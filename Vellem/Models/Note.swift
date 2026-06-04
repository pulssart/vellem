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
        decisionContext = try container.decodeIfPresent(NoteDecisionContext.self, forKey: .decisionContext)
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

    var isFromCodex: Bool {
        guard let sourceApp else { return false }
        return sourceApp.localizedCaseInsensitiveContains("codex")
    }

    var isFromClaude: Bool {
        guard let sourceApp else { return false }
        return sourceApp.localizedCaseInsensitiveContains("claude")
    }
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

    init(
        sourceDetail: String = "",
        capturedAt: Date = .now,
        decisionTitle: String = "",
        effect: DecisionEffect = .influenced,
        expiresAt: Date? = nil,
        validationRule: String = "",
        resolvedAt: Date? = nil,
        updatedAt: Date = .now
    ) {
        self.sourceDetail = sourceDetail
        self.capturedAt = capturedAt
        self.decisionTitle = decisionTitle
        self.effect = effect
        self.expiresAt = expiresAt
        self.validationRule = validationRule
        self.resolvedAt = resolvedAt
        self.updatedAt = updatedAt
    }

    var isEmpty: Bool {
        sourceDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            decisionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            validationRule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            expiresAt == nil &&
            resolvedAt == nil
    }

    func status(relativeTo date: Date = .now) -> DecisionContextStatus {
        if resolvedAt != nil {
            return .resolved
        }

        guard let expiresAt else {
            return .active
        }

        if expiresAt < date {
            return .expired
        }

        let reviewThreshold = Calendar.current.date(byAdding: .day, value: 3, to: date) ?? date
        return expiresAt <= reviewThreshold ? .needsReview : .active
    }
}

enum DecisionEffect: String, CaseIterable, Codable, Hashable, Identifiable {
    case influenced
    case confirmed
    case blocked
    case cancelled
    case questioned

    var id: String { rawValue }

    var label: String {
        switch self {
        case .influenced:
            return "Influenced"
        case .confirmed:
            return "Confirmed"
        case .blocked:
            return "Blocked"
        case .cancelled:
            return "Cancelled"
        case .questioned:
            return "Questioned"
        }
    }
}

enum DecisionContextStatus: String, Codable, Hashable {
    case active
    case needsReview
    case expired
    case resolved

    var label: String {
        switch self {
        case .active:
            return "Active"
        case .needsReview:
            return "Review"
        case .expired:
            return "Expired"
        case .resolved:
            return "Resolved"
        }
    }

    var systemImage: String {
        switch self {
        case .active:
            return "checkmark.circle"
        case .needsReview:
            return "clock.badge.exclamationmark"
        case .expired:
            return "exclamationmark.triangle"
        case .resolved:
            return "checkmark.seal"
        }
    }
}
