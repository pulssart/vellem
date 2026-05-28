import Foundation
import NaturalLanguage

/// Local semantic index over notes using Apple's NaturalLanguage framework.
///
/// - Detects each note's dominant language (French/English typically) with
///   `NLLanguageRecognizer`, then embeds via `NLEmbedding.sentenceEmbedding`.
/// - Caches normalized vectors keyed by note ID in `embeddings.json` inside
///   the shared App Group container so the MCP binary (a short-lived process)
///   doesn't re-embed every call.
/// - Falls back to averaging word vectors when no sentence embedder exists for
///   the detected language.
///
/// Designed for the MCP server's single-process lifetime: we lazy-load
/// embedders per language and persist the cache only when something changed.
final class SemanticIndex {
    struct CacheEntry: Codable {
        let hash: String           // change-detection hash of canonical text
        let lang: String           // BCP-47 language code that produced the vector
        let vector: [Double]       // L2-normalized
    }

    private let cacheURL: URL
    private var cache: [String: CacheEntry] = [:]
    private var cacheDirty = false
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // Lazy-instantiated per-language embedders (loading them is non-trivial).
    private var sentenceEmbedders: [NLLanguage: NLEmbedding] = [:]
    private var wordEmbedders: [NLLanguage: NLEmbedding] = [:]

    init() {
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "MKAFV9VL9V.com.adriendonot.Vellem"
        ) ?? FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Group Containers/MKAFV9VL9V.com.adriendonot.Vellem")
        self.cacheURL = container.appending(path: "embeddings.json")
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        self.encoder = enc
        self.decoder = JSONDecoder()
        loadCache()
    }

    // MARK: - Public API

    /// Ensure embeddings exist for every supplied note. Runs lazily — notes
    /// whose hash matches the cached entry are skipped. Persists the cache
    /// once at the end if anything changed.
    func ensureEmbeddings(for notes: [Note]) {
        for note in notes {
            let canonical = canonicalize(noteText(note))
            guard !canonical.isEmpty else { continue }
            let hash = contentHash(canonical)
            let key = note.id.uuidString
            if let existing = cache[key], existing.hash == hash { continue }

            guard let result = embedCanonical(canonical) else { continue }
            cache[key] = CacheEntry(
                hash: hash,
                lang: result.language.rawValue,
                vector: result.vector
            )
            cacheDirty = true
        }
        flushIfNeeded()
    }

    /// Rank `notes` by semantic similarity to a free-form query. Returns the
    /// top-`limit` (note, score) pairs in descending score order.
    func topMatches(forQuery query: String, in notes: [Note], limit: Int) -> [(note: Note, score: Double)] {
        ensureEmbeddings(for: notes)
        guard let queryEmbedding = embed(query) else { return [] }
        let scored: [(Note, Double)] = notes.compactMap { note in
            guard let entry = cache[note.id.uuidString] else { return nil }
            return (note, cosine(queryEmbedding.vector, entry.vector))
        }
        return Array(scored.sorted { $0.1 > $1.1 }.prefix(max(1, limit)))
    }

    /// Rank `notes` by semantic similarity to the note with `id`. The base
    /// note is excluded from results.
    func topMatches(forNoteID id: UUID, in notes: [Note], limit: Int) -> [(note: Note, score: Double)] {
        ensureEmbeddings(for: notes)
        guard let baseEntry = cache[id.uuidString] else { return [] }
        let scored: [(Note, Double)] = notes.compactMap { note in
            guard note.id != id, let entry = cache[note.id.uuidString] else { return nil }
            return (note, cosine(baseEntry.vector, entry.vector))
        }
        return Array(scored.sorted { $0.1 > $1.1 }.prefix(max(1, limit)))
    }

    /// Remove cached entries whose note no longer exists. Called opportunistically
    /// to keep `embeddings.json` from growing forever.
    func pruneMissing(keeping noteIDs: Set<UUID>) {
        let liveKeys = Set(noteIDs.map(\.uuidString))
        let before = cache.count
        cache = cache.filter { liveKeys.contains($0.key) }
        if cache.count != before {
            cacheDirty = true
            flushIfNeeded()
        }
    }

    // MARK: - Embedding pipeline

    /// Embed an arbitrary free-form query the same way notes are embedded.
    private func embed(_ text: String) -> (vector: [Double], language: NLLanguage)? {
        let canonical = canonicalize(text)
        guard !canonical.isEmpty else { return nil }
        return embedCanonical(canonical)
    }

    private func embedCanonical(_ canonical: String) -> (vector: [Double], language: NLLanguage)? {
        // Sentence embedders cap at ~1000 chars in practice; we truncate to
        // keep latency predictable on long notes.
        let truncated = String(canonical.prefix(1500))
        let language = detectLanguage(truncated)

        if let sentence = sentenceEmbedder(for: language),
           let vec = sentence.vector(for: truncated) {
            return (normalize(vec), language)
        }
        // Sentence embedder might exist for English but not for the detected
        // language — try English as a universal fallback.
        if language != .english,
           let sentence = sentenceEmbedder(for: .english),
           let vec = sentence.vector(for: truncated) {
            return (normalize(vec), .english)
        }
        // Final fallback: average per-token word vectors.
        if let vec = averagedWordVector(truncated, language: language) {
            return (normalize(vec), language)
        }
        if language != .english,
           let vec = averagedWordVector(truncated, language: .english) {
            return (normalize(vec), .english)
        }
        return nil
    }

    private func averagedWordVector(_ text: String, language: NLLanguage) -> [Double]? {
        guard let embedder = wordEmbedder(for: language) else { return nil }
        let dim = embedder.dimension
        guard dim > 0 else { return nil }

        var sum = [Double](repeating: 0, count: dim)
        var count = 0
        text.unicodeScalars
            .split(whereSeparator: { !CharacterSet.alphanumerics.contains($0) })
            .map { String($0).lowercased() }
            .forEach { token in
                guard !token.isEmpty,
                      let vec = embedder.vector(for: token),
                      vec.count == dim else { return }
                for i in 0..<dim { sum[i] += vec[i] }
                count += 1
            }
        guard count > 0 else { return nil }
        return sum.map { $0 / Double(count) }
    }

    private func sentenceEmbedder(for language: NLLanguage) -> NLEmbedding? {
        if let cached = sentenceEmbedders[language] { return cached }
        if let fresh = NLEmbedding.sentenceEmbedding(for: language) {
            sentenceEmbedders[language] = fresh
            return fresh
        }
        return nil
    }

    private func wordEmbedder(for language: NLLanguage) -> NLEmbedding? {
        if let cached = wordEmbedders[language] { return cached }
        if let fresh = NLEmbedding.wordEmbedding(for: language) {
            wordEmbedders[language] = fresh
            return fresh
        }
        return nil
    }

    // MARK: - Text preparation

    /// Concatenate title + body into one blob fed to the embedder.
    private func noteText(_ note: Note) -> String {
        let title = (note.generatedTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { return note.text }
        return title + "\n" + note.text
    }

    /// Strip markdown noise so semantically-equivalent variants hash and embed
    /// the same: heading markers, list bullets, emphasis, fenced code fences,
    /// links/images (keep the visible text), then collapse whitespace + lower.
    private func canonicalize(_ text: String) -> String {
        var t = text

        // Images ![alt](url) → alt
        t = t.replacing(/!\[([^\]]*)\]\([^)]+\)/, with: "$1")
        // Links [text](url) → text
        t = t.replacing(/\[([^\]]+)\]\([^)]+\)/, with: "$1")
        // Fenced code blocks
        t = t.replacing(/```[\s\S]*?```/, with: " ")
        // Inline code
        t = t.replacing(/`[^`]+`/, with: " ")
        // Heading markers / blockquote / list bullets at line start
        t = t.replacing(/(?m)^\s{0,3}#{1,6}\s*/, with: "")
        t = t.replacing(/(?m)^\s{0,3}>\s*/, with: "")
        t = t.replacing(/(?m)^\s*[-*+]\s+/, with: "")
        t = t.replacing(/(?m)^\s*\d+[.)]\s+/, with: "")
        // Emphasis markers
        for marker in ["**", "__", "~~", "*", "_"] {
            t = t.replacingOccurrences(of: marker, with: " ")
        }
        // Collapse whitespace
        let tokens = t.unicodeScalars
            .split(whereSeparator: { CharacterSet.whitespacesAndNewlines.contains($0) })
            .map { String($0) }
        return tokens.joined(separator: " ").lowercased()
    }

    private func detectLanguage(_ text: String) -> NLLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage ?? .english
    }

    // MARK: - Vector math

    private func normalize(_ v: [Double]) -> [Double] {
        let norm = sqrt(v.reduce(0.0) { $0 + $1 * $1 })
        guard norm > 1e-9 else { return v }
        return v.map { $0 / norm }
    }

    private func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var s = 0.0
        for i in 0..<a.count { s += a[i] * b[i] }
        return s
    }

    /// Lightweight non-cryptographic hash (FNV-1a 64-bit) — change detection,
    /// not security. Crypto-level digests would be wasteful for this volume.
    private func contentHash(_ text: String) -> String {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x0000_0100_0000_01b3
        }
        return String(h, radix: 16)
    }

    // MARK: - Persistence

    private func loadCache() {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return }
        do {
            let data = try Data(contentsOf: cacheURL)
            guard !data.isEmpty else { return }
            cache = try decoder.decode([String: CacheEntry].self, from: data)
        } catch {
            // Cache is corrupted or schema-incompatible — fall back to empty.
            cache = [:]
        }
    }

    private func flushIfNeeded() {
        guard cacheDirty else { return }
        do {
            try FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(cache)
            try data.write(to: cacheURL, options: [.atomic])
            cacheDirty = false
        } catch {
            // Best effort — silent failure is fine, next call recomputes.
        }
    }
}
