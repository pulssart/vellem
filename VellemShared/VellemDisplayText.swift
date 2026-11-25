import Foundation

extension String {
    func vellemTitle(explicit: String?, format: String?) -> String {
        if let explicit {
            let title = explicit.vellemDisplayText
            if !title.isEmpty { return title }
        }
        let opening = prefix(4096).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = opening.split(whereSeparator: \.isNewline).first else { return VellemLanguage.text("Untitled") }
        let line = String(first)
        let title: String
        switch format {
        case "json":
            if opening.hasPrefix("{") { return VellemLanguage.text("JSON object") }
            if opening.hasPrefix("[") { return VellemLanguage.text("JSON array") }
            return "JSON"
        case "code", "text": title = line
        default:
            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                let language = line.drop(while: { $0 == "`" || $0 == "~" }).trimmingCharacters(in: .whitespaces)
                return language.isEmpty ? "Code" : "Code · " + String(language.prefix(40))
            }
            title = line.vellemDisplayText
        }
        if title.isEmpty { return VellemLanguage.text("Untitled") }
        if title.count <= 110 { return title }
        let excerpt = title.prefix(108)
        let boundary = excerpt.lastIndex(where: \.isWhitespace) ?? excerpt.endIndex
        let words = excerpt[..<boundary]
        return String(words.count > 75 ? words : excerpt) + "…"
    }

    func vellemPreview(removingTitle title: String, format: String? = nil) -> String {
        // Inbox rows only need a short excerpt, including for multi-megabyte outputs.
        let literal = (format ?? "markdown") != "markdown"
        let lines = prefix(4096).split(whereSeparator: \.isNewline)
        guard !lines.isEmpty else { return VellemLanguage.text("Empty note") }
        var first = true
        for line in lines {
            let raw = String(line).trimmingCharacters(in: .whitespaces)
            if raw.isEmpty { continue }
            if format == "json" && ["{", "}", "[", "]"].contains(raw) { continue }
            if !literal && (raw.hasPrefix("```") || raw.hasPrefix("~~~") ||
                            raw.wholeMatch(of: /[|:\-\s]+/) != nil) { continue }
            let excerpt = literal ? raw : raw.vellemDisplayText
            if excerpt.isEmpty { continue }
            if !first || excerpt.localizedCaseInsensitiveCompare(title) != .orderedSame {
                return String(excerpt.prefix(300))
            }
            first = false
        }
        return first ? VellemLanguage.text("Empty note") : title
    }

    var vellemDisplayText: String {
        var line = trimmingCharacters(in: .whitespacesAndNewlines)
            .replacing(/^(?:#{1,6}\s+|>\s*|[-*+]\s+|\d+[.)]\s+)/, with: "")
            .replacing(/^\[[ xX]\]\s+/, with: "")
            .replacing(/(?i)<\/?(?:html|body|div|span|p|h[1-6]|table|thead|tbody|tr|th|td|figure|figcaption|caption|br|b|strong|i|em|ul|ol|li|code|pre)\b[^>]*>/, with: " ")
        if line.hasPrefix("|") || line.hasSuffix("|") {
            line = line.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                .replacing(/\s*\|\s*/, with: " · ")
        }
        if let inline = try? AttributedString(markdown: line, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            line = String(inline.characters)
        }
        return line.replacing(/\s+/, with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
