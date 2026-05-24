import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum EditAction: String, CaseIterable, Identifiable {
    case format
    case proofread
    case rewrite
    case friendly
    case professional
    case concise
    case summary
    case keyPoints
    case list
    case title

    static var manualActions: [EditAction] {
        [.proofread, .rewrite, .friendly, .professional, .concise, .summary, .keyPoints, .list, .title]
    }

    var id: String { rawValue }

    var label: String {
        switch self {
        case .format: "Format"
        case .proofread: "Proofread"
        case .rewrite: "Rewrite"
        case .friendly: "Friendly"
        case .professional: "Professional"
        case .concise: "Concise"
        case .summary: "Summary"
        case .keyPoints: "Key Points"
        case .list: "List"
        case .title: "Title"
        }
    }

    var systemImage: String {
        switch self {
        case .format: "textformat"
        case .proofread: "checkmark.seal"
        case .rewrite: "arrow.triangle.2.circlepath"
        case .friendly: "face.smiling"
        case .professional: "briefcase"
        case .concise: "text.line.first.and.arrowtriangle.forward"
        case .summary: "text.alignleft"
        case .keyPoints: "list.bullet.indent"
        case .list: "list.bullet"
        case .title: "textformat.size"
        }
    }

    func prompt(for text: String) -> String {
        switch self {
        case .format:
            """
            Format this note into clean Markdown.
            Keep the original language, meaning, facts, names, and numbers.
            Preserve every Markdown image line exactly unchanged, including URLs and alt text.
            Add a clear title as a Markdown heading when useful.
            Use headings, short paragraphs, bullets, bold, and italic only when they improve readability.
            When using bullet lists, put a blank line between each bullet item so the list stays airy.
            Do not invent information.
            Do not wrap the result in a code block.
            Return only the formatted note.

            \(text)
            """
        case .proofread:
            "Proofread this note. Fix spelling, grammar, punctuation, and obvious typos. Keep the original language, meaning, structure, formatting, facts, names, and numbers. Return only the corrected note.\n\n\(text)"
        case .rewrite:
            "Rewrite this note clearly and naturally. Keep the original language, meaning, facts, names, and numbers. Return only the rewritten note.\n\n\(text)"
        case .friendly:
            "Rewrite this note in a friendly, natural tone. Keep the original language, meaning, facts, names, and numbers. Return only the edited note.\n\n\(text)"
        case .professional:
            "Rewrite this note in a professional, clear tone. Keep the original language, meaning, facts, names, and numbers. Return only the edited note.\n\n\(text)"
        case .concise:
            "Make this note more concise without losing useful details. Keep the original language, meaning, facts, names, and numbers. Return only the edited note.\n\n\(text)"
        case .summary:
            "Summarize this note clearly. Keep the original language and the most important facts, names, and numbers. Return only the summary.\n\n\(text)"
        case .keyPoints:
            "Extract the key points from this note. Keep the original language. Use concise bullet points. Put a blank line between each bullet item so the list stays airy. Return only the key points.\n\n\(text)"
        case .list:
            "Turn this note into a clear bullet list. Keep the original language, meaning, facts, names, and numbers. Put a blank line between each bullet item so the list stays airy. Return only the list.\n\n\(text)"
        case .title:
            "Create a natural title for this note. Detect the note language and write the title in that exact same language. If the note is French, the title must be French. Use 3 or 4 words maximum. Return only the title.\n\n\(text)"
        }
    }
}

enum TranslationLanguage: String, CaseIterable, Identifiable {
    case english
    case french
    case spanish
    case german
    case italian
    case portuguese

    var id: String { rawValue }

    var label: String {
        switch self {
        case .english: "English"
        case .french: "French"
        case .spanish: "Spanish"
        case .german: "German"
        case .italian: "Italian"
        case .portuguese: "Portuguese"
        }
    }

    var systemImage: String { "globe" }
}

enum NoteEditError: LocalizedError {
    case unavailable
    case empty

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Apple Foundation Models is not available on this Mac."
        case .empty:
            "Write something first."
        }
    }
}

struct FoundationNoteEditor {
    func edit(_ text: String, action: EditAction) async throws -> String {
        try await respond(to: action.prompt(for: text), text: text)
    }

    func title(for text: String) async throws -> String {
        try await respond(to: EditAction.title.prompt(for: text), text: text)
    }

    func translate(_ text: String, to language: TranslationLanguage) async throws -> String {
        let prompt = "Translate this note to \(language.label). Keep the meaning and formatting. Return only the translated note.\n\n\(text)"
        return try await respond(to: prompt, text: text)
    }

    private func respond(to prompt: String, text: String) async throws -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw NoteEditError.empty }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif

        throw NoteEditError.unavailable
    }
}
