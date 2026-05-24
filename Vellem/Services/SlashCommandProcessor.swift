import Foundation

struct SlashCommand: Identifiable, Hashable {
    let id: String
    let aliases: [String]
    let label: String
    let hint: String
    let systemImage: String
    let replacement: String?
    let aiAction: EditAction?

    var keyword: String { id }
    var keywordDisplay: String { "/\(id)" }
}

enum SlashCommandRegistry {
    static let all: [SlashCommand] = [
        SlashCommand(
            id: "todo", aliases: ["task"],
            label: "Todo",
            hint: "Checkbox item you can tick off",
            systemImage: "checklist",
            replacement: "- [ ] ", aiAction: nil
        ),
        SlashCommand(
            id: "done", aliases: [],
            label: "Done todo",
            hint: "Pre-checked checkbox",
            systemImage: "checkmark.square",
            replacement: "- [x] ", aiAction: nil
        ),
        SlashCommand(
            id: "h1", aliases: ["title1"],
            label: "Heading 1",
            hint: "Large section title",
            systemImage: "textformat.size.larger",
            replacement: "# ", aiAction: nil
        ),
        SlashCommand(
            id: "h2", aliases: ["title2"],
            label: "Heading 2",
            hint: "Medium section title",
            systemImage: "textformat.size",
            replacement: "## ", aiAction: nil
        ),
        SlashCommand(
            id: "h3", aliases: ["title3"],
            label: "Heading 3",
            hint: "Subsection title",
            systemImage: "textformat.size.smaller",
            replacement: "### ", aiAction: nil
        ),
        SlashCommand(
            id: "bullet", aliases: ["list", "li"],
            label: "Bullet",
            hint: "Bulleted list item",
            systemImage: "list.bullet",
            replacement: "- ", aiAction: nil
        ),
        SlashCommand(
            id: "quote", aliases: ["q"],
            label: "Quote",
            hint: "Block quote",
            systemImage: "quote.opening",
            replacement: "> ", aiAction: nil
        ),
        SlashCommand(
            id: "divider", aliases: ["hr"],
            label: "Divider",
            hint: "Horizontal separator",
            systemImage: "minus",
            replacement: "\n---\n\n", aiAction: nil
        ),
        SlashCommand(
            id: "date", aliases: [],
            label: "Today's date",
            hint: "Insert today's date",
            systemImage: "calendar",
            replacement: "__DATE__", aiAction: nil
        ),
        SlashCommand(
            id: "time", aliases: [],
            label: "Current time",
            hint: "Insert the current time",
            systemImage: "clock",
            replacement: "__TIME__", aiAction: nil
        ),
        SlashCommand(
            id: "format", aliases: [],
            label: "Format with AI",
            hint: "Clean up the note structure",
            systemImage: "textformat",
            replacement: nil, aiAction: .format
        ),
        SlashCommand(
            id: "summary", aliases: ["summarize"],
            label: "Summarize",
            hint: "Replace with a summary",
            systemImage: "text.alignleft",
            replacement: nil, aiAction: .summary
        ),
        SlashCommand(
            id: "rewrite", aliases: [],
            label: "Rewrite",
            hint: "Rewrite the note clearly",
            systemImage: "arrow.triangle.2.circlepath",
            replacement: nil, aiAction: .rewrite
        ),
        SlashCommand(
            id: "proofread", aliases: ["fix"],
            label: "Proofread",
            hint: "Fix grammar and typos",
            systemImage: "checkmark.seal",
            replacement: nil, aiAction: .proofread
        ),
        SlashCommand(
            id: "concise", aliases: ["short"],
            label: "Make concise",
            hint: "Shorten the note",
            systemImage: "text.line.first.and.arrowtriangle.forward",
            replacement: nil, aiAction: .concise
        ),
        SlashCommand(
            id: "keypoints", aliases: ["key", "points"],
            label: "Key points",
            hint: "Extract the main bullets",
            systemImage: "list.bullet.indent",
            replacement: nil, aiAction: .keyPoints
        ),
        SlashCommand(
            id: "title", aliases: [],
            label: "Generate title",
            hint: "Set an AI-generated title",
            systemImage: "textformat.size",
            replacement: nil, aiAction: .title
        ),
        SlashCommand(
            id: "friendly", aliases: [],
            label: "Friendly tone",
            hint: "Rewrite with a friendly tone",
            systemImage: "face.smiling",
            replacement: nil, aiAction: .friendly
        ),
        SlashCommand(
            id: "pro", aliases: ["professional"],
            label: "Professional tone",
            hint: "Rewrite with a professional tone",
            systemImage: "briefcase",
            replacement: nil, aiAction: .professional
        )
    ]

    static func match(_ word: String) -> SlashCommand? {
        let key = word.lowercased()
        return all.first { $0.id == key || $0.aliases.contains(key) }
    }

    private static func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: .now)
    }

    private static func timeString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: .now)
    }
}

struct SlashCommandResult {
    var text: String
    var aiAction: EditAction?
}

enum SlashCommandProcessor {
    /// Detects when the user just finished typing a slash command (terminated by space or newline)
    /// and returns the rewritten text plus an optional AI action to run.
    static func process(previous: String, current: String) -> SlashCommandResult? {
        guard current.count > previous.count else { return nil }
        guard let last = current.last, last == " " || last == "\n" else { return nil }

        // Strip trailing trigger character.
        let endTrigger = current.index(before: current.endIndex)
        let beforeTrigger = current[..<endTrigger]

        // Find start of last word (after a whitespace/newline boundary).
        let wordStart = beforeTrigger.lastIndex(where: { $0 == " " || $0 == "\n" || $0 == "\t" })
            .map { beforeTrigger.index(after: $0) } ?? beforeTrigger.startIndex
        let word = String(beforeTrigger[wordStart..<beforeTrigger.endIndex])

        guard word.hasPrefix("/") else { return nil }
        let keyword = String(word.dropFirst())
        guard !keyword.isEmpty else { return nil }
        guard let command = SlashCommandRegistry.match(keyword) else { return nil }

        // Build replacement text.
        let prefix = String(current[current.startIndex..<wordStart])
        var rewritten = prefix
        if let rawReplacement = command.replacement {
            let replacement = resolve(rawReplacement)
            // Replacements that should start on a fresh line.
            let needsNewline = !replacement.hasPrefix("\n") &&
                !isLineStart(prefix) &&
                shouldStartOnNewLine(command)
            if needsNewline {
                rewritten += "\n"
            }
            rewritten += replacement
        }

        return SlashCommandResult(text: rewritten, aiAction: command.aiAction)
    }

    private static func resolve(_ replacement: String) -> String {
        switch replacement {
        case "__DATE__":
            let f = DateFormatter()
            f.dateStyle = .long; f.timeStyle = .none
            return f.string(from: .now)
        case "__TIME__":
            let f = DateFormatter()
            f.dateStyle = .none; f.timeStyle = .short
            return f.string(from: .now)
        default:
            return replacement
        }
    }

    private static func isLineStart(_ prefix: String) -> Bool {
        prefix.isEmpty || prefix.hasSuffix("\n")
    }

    private static func shouldStartOnNewLine(_ command: SlashCommand) -> Bool {
        switch command.id {
        case "todo", "done", "h1", "h2", "h3", "bullet", "quote", "divider":
            return true
        default:
            return false
        }
    }
}
