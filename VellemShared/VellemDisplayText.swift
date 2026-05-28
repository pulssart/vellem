import Foundation

extension String {
    var vellemDisplayText: String {
        var cleaned = self
            .replacing(/\!\[([^\]]*)\]\([^)]+\)/, with: "$1")
            .replacing(/\[([^\]]+)\]\([^)]+\)/, with: "$1")
            .replacing(/(?m)^\s{0,3}#{1,6}\s*/, with: "")
            .replacing(/(?m)^\s{0,3}>\s*/, with: "")
            .replacing(/(?m)^\s*[-*+]\s+/, with: "")
            .replacing(/(?m)^\s*\d+[.)]\s+/, with: "")
            .replacingOccurrences(of: "\n", with: " ")

        for marker in ["**", "__", "~~", "`", "*", "_", "#"] {
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }

        return cleaned
            .replacing(/\s+/, with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
