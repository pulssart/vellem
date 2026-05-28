import Foundation

extension NotesStore {
    nonisolated func pruneEmbeddingCache(keeping noteIDs: Set<Note.ID>) {
        let liveKeys = Set(noteIDs.map(\.uuidString))
        let cacheURL = AppGroup.embeddingsURL

        Task.detached(priority: .utility) {
            guard FileManager.default.fileExists(atPath: cacheURL.path) else { return }

            do {
                let data = try Data(contentsOf: cacheURL)
                guard !data.isEmpty,
                      var cache = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return
                }

                let originalCount = cache.count
                cache = cache.filter { liveKeys.contains($0.key) }
                guard cache.count != originalCount else { return }

                let prunedData = try JSONSerialization.data(
                    withJSONObject: cache,
                    options: [.sortedKeys]
                )
                try FileManager.default.createDirectory(
                    at: cacheURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try prunedData.write(to: cacheURL, options: [.atomic])
            } catch {
                // Best effort. The semantic tool can rebuild stale or missing entries later.
            }
        }
    }
}
