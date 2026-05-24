import Foundation

struct Note: Identifiable, Codable, Hashable {
    var id: UUID
    var text: String
    var generatedTitle: String?
    var kind: NoteKind
    var sourceApp: String?
    var sourceURL: URL?
    var createdAt: Date
    var updatedAt: Date
    var folderID: UUID?

    init(
        id: UUID = UUID(),
        text: String,
        generatedTitle: String? = nil,
        kind: NoteKind = .regular,
        sourceApp: String? = nil,
        sourceURL: URL? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        folderID: UUID? = nil
    ) {
        self.id = id
        self.text = text
        self.generatedTitle = generatedTitle
        self.kind = kind
        self.sourceApp = sourceApp
        self.sourceURL = sourceURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.folderID = folderID
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case generatedTitle
        case kind
        case sourceApp
        case sourceURL
        case createdAt
        case updatedAt
        case folderID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        generatedTitle = try container.decodeIfPresent(String.self, forKey: .generatedTitle)
        kind = try container.decodeIfPresent(NoteKind.self, forKey: .kind) ?? .regular
        sourceApp = try container.decodeIfPresent(String.self, forKey: .sourceApp)
        sourceURL = try container.decodeIfPresent(URL.self, forKey: .sourceURL)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        folderID = try container.decodeIfPresent(UUID.self, forKey: .folderID)
    }

    var title: String {
        if let generatedTitle,
           !generatedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let cleanedTitle = generatedTitle.vellemDisplayText
            return cleanedTitle.isEmpty ? "Untitled" : cleanedTitle
        }

        let line = text
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let cleanedTitle = line.vellemDisplayText
        return cleanedTitle.isEmpty ? "Untitled" : cleanedTitle
    }

    var preview: String {
        let cleaned = text
            .vellemDisplayText

        return cleaned.isEmpty ? "Empty note" : cleaned
    }

    var wordCount: Int {
        text
            .split { $0.isWhitespace || $0.isNewline }
            .count
    }

    var isDailyNote: Bool {
        kind == .daily
    }
}

enum NoteKind: String, Codable, Hashable {
    case regular
    case daily
}

private extension String {
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
