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
    var mailbox: String?

    var displayPath: String { mailbox.map { "\($0) / \(name)" } ?? name }

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
        kind: FolderKind = .regular,
        mailbox: String? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.color = color
        self.kind = kind
        self.mailbox = mailbox
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt
        case color
        case kind
        case mailbox
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        mailbox = try c.decodeIfPresent(String.self, forKey: .mailbox)
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

enum SidebarMailbox: Hashable {
    case inbox, today, folders, captures
    case agent(InboxAgent)

    var title: String {
        switch self {
        case .inbox: "All inboxes"
        case .today: "Today"
        case .folders: "Folders"
        case .captures: "Quick captures"
        case .agent(let agent): agent.rawValue
        }
    }

    var folderKey: String? { self == .folders ? nil : title }

    func visibleFolders(in folders: [Folder], notes: [Note]) -> [Folder] {
        guard case .agent(let agent) = self else {
            return folders.filter { !$0.isSmart && (self == .folders || $0.mailbox == folderKey) }
        }

        // A shared folder can appear in several agents’ sidebars without changing its owner.
        let contributedTo = Set(notes.compactMap { note -> UUID? in
            guard let id = note.folderID, InboxAgent.origin(of: note) == agent else { return nil }
            return id
        })
        return folders.filter { folder in
            !folder.isSmart && (folder.mailbox == agent.rawValue || (folder.mailbox == nil && contributedTo.contains(folder.id)))
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    init(folder: Folder) {
        switch folder.kind {
        case .smartServices: self = .captures
        case .smartPromptLibrary: self = .folders
        case .smartClaude: self = .agent(.claude)
        case .smartCodex: self = .agent(.codex)
        case .regular:
            if let name = folder.mailbox, let agent = InboxAgent(rawValue: name) {
                self = .agent(agent)
            } else {
                self = [Self.inbox, .today, .captures].first { $0.title == folder.mailbox } ?? .folders
            }
        }
    }
}
