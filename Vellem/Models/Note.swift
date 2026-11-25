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
    var isRead: Bool
    var outputFormat: OutputFormat?
    var conversation: ReplyConversation?
    var replies: [NoteReply]?
    // Retain metadata in archives created before the agent inbox.
    var decisionContext: NoteDecisionContext?

    init(
        id: UUID = UUID(),
        text: String,
        generatedTitle: String? = nil,
        kind: NoteKind = .regular,
        sourceApp: String? = nil,
        sourceURL: URL? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        folderID: UUID? = nil,
        isRead: Bool = false,
        outputFormat: OutputFormat? = nil,
        decisionContext: NoteDecisionContext? = nil
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
        self.isRead = isRead
        self.outputFormat = outputFormat
        self.decisionContext = decisionContext
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
        case isRead
        case outputFormat
        case conversation, replies
        case decisionContext
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
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? true
        outputFormat = try container.decodeIfPresent(OutputFormat.self, forKey: .outputFormat)
        conversation = try container.decodeIfPresent(ReplyConversation.self, forKey: .conversation)
        replies = try container.decodeIfPresent([NoteReply].self, forKey: .replies)
        decisionContext = try container.decodeIfPresent(NoteDecisionContext.self, forKey: .decisionContext)
    }

    var title: String {
        text.vellemTitle(explicit: generatedTitle, format: outputFormat?.rawValue)
    }

    var preview: String {
        text.vellemPreview(removingTitle: title, format: outputFormat?.rawValue)
    }

    var wordCount: Int {
        text
            .split { $0.isWhitespace || $0.isNewline }
            .count
    }

    var isDailyNote: Bool {
        kind == .daily
    }

    var isFromCodex: Bool {
        guard let sourceApp else { return false }
        return sourceApp.localizedCaseInsensitiveContains("codex")
    }

    var isFromClaude: Bool {
        guard let sourceApp else { return false }
        return sourceApp.localizedCaseInsensitiveContains("claude")
    }
}

enum OutputFormat: String, Codable, CaseIterable {
    case markdown, text, json, code
}

enum NoteKind: String, Codable, Hashable {
    case regular
    case daily
}

struct NoteDecisionContext: Codable, Hashable {
    var sourceDetail: String
    var capturedAt: Date
    var decisionTitle: String
    var effect: DecisionEffect
    var expiresAt: Date?
    var validationRule: String
    var resolvedAt: Date?
    var updatedAt: Date
}

enum DecisionEffect: String, Codable, Hashable {
    case influenced, confirmed, blocked, cancelled, questioned
}

// Provenance is independent of where a note is filed.
enum InboxAgent: String, CaseIterable {
    case chatGPT = "ChatGPT"
    case codex = "Codex"
    case claude = "Claude"
    case grok = "Grok"
    case gemini = "Gemini"
    case grokbot = "Grokbot"

    static func identify(_ name: String?) -> Self? {
        guard let name else { return nil }
        let tokens = name.lowercased().split { !$0.isLetter && !$0.isNumber }
        if tokens.contains("grokbot") || tokens.contains("grokbots") || (tokens.contains("grok") && (tokens.contains("bot") || tokens.contains("bots"))) { return .grokbot }
        return allCases.first { tokens.contains(Substring($0.rawValue.lowercased())) }
    }

    static func origin(of note: Note) -> Self? {
        if let agent = identify(note.sourceApp) { return agent }
        guard let host = note.sourceURL?.host?.lowercased() else { return nil }
        for (domain, agent) in webOrigins where host == domain || host.hasSuffix("." + domain) {
            return agent
        }
        return nil
    }

    private static let webOrigins: [(String, Self)] = [
        ("chatgpt.com", .chatGPT), ("chat.openai.com", .chatGPT),
        ("claude.ai", .claude), ("grok.com", .grok), ("gemini.google.com", .gemini)
    ]
}

struct ReplyConversation: Codable, Hashable, Sendable {
    enum Provider: String, Codable, Sendable { case codex = "Codex", claude = "Claude" }

    let provider: Provider
    let sessionID: UUID
    let directory: String
}

struct NoteReply: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let question: String
    var answer: String
    let date: Date
    enum Delivery: String, Codable { case queued, failed }
    var delivery: Delivery? = nil
}
