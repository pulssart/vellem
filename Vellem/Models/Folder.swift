import Foundation

enum FolderKind: String, Codable, Hashable {
    case regular
    case smartServices
    case smartClaude
    case smartCodex
    case smartPromptLibrary

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = FolderKind(rawValue: rawValue) ?? .regular
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct Folder: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var createdAt: Date
    var color: String?
    var kind: FolderKind

    var isSmart: Bool { kind != .regular }

    var systemImage: String {
        switch kind {
        case .smartServices:
            "bolt.fill"
        case .smartClaude:
            "terminal.fill"
        case .smartCodex:
            "terminal.fill"
        case .smartPromptLibrary:
            "books.vertical.fill"
        case .regular:
            "folder.fill"
        }
    }

    var outlineSystemImage: String {
        switch kind {
        case .smartServices:
            "bolt"
        case .smartClaude:
            "terminal"
        case .smartCodex:
            "terminal"
        case .smartPromptLibrary:
            "books.vertical"
        case .regular:
            "folder"
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        color: String? = nil,
        kind: FolderKind = .regular
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.color = color
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt
        case color
        case kind
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        color = try c.decodeIfPresent(String.self, forKey: .color)
        // Tolerate unknown legacy kinds (e.g. removed enum cases on disk) by
        // falling back to .regular instead of failing the whole folder array.
        if let rawKind = try c.decodeIfPresent(String.self, forKey: .kind) {
            kind = FolderKind(rawValue: rawKind) ?? .regular
        } else {
            kind = .regular
        }
    }
}

enum FolderColor: String, CaseIterable, Identifiable {
    case yellow, orange, red, pink, purple, blue, teal, green, gray

    var id: String { rawValue }

    var label: String {
        switch self {
        case .yellow: "Yellow"
        case .orange: "Orange"
        case .red:    "Red"
        case .pink:   "Pink"
        case .purple: "Purple"
        case .blue:   "Blue"
        case .teal:   "Teal"
        case .green:  "Green"
        case .gray:   "Gray"
        }
    }

    static func named(_ raw: String?) -> FolderColor? {
        guard let raw else { return nil }
        return FolderColor(rawValue: raw.lowercased())
    }
}
