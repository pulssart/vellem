import SwiftUI

/// Read-only-feeling rendered markdown view. Edits go back through the binding when
/// the user toggles a todo checkbox.
struct MarkdownRenderedView: View {
    @Binding var text: String
    var textSizeStep: Int = 0
    var contentPadding: EdgeInsets = EdgeInsets(top: 18, leading: 20, bottom: 18, trailing: 20)
    @AppAccent private var accent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(parsedBlocks.enumerated()), id: \.offset) { _, block in
                    blockView(block)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, contentPadding.top)
            .padding(.bottom, contentPadding.bottom)
            .padding(.leading, contentPadding.leading)
            .padding(.trailing, contentPadding.trailing)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .textSelection(.enabled)
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Parsing

    private var parsedBlocks: [RenderedBlock] {
        var blocks: [RenderedBlock] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var index = 0
        while index < lines.count {
            let rawLine = lines[index]
            let cleaned = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty {
                blocks.append(.space)
                index += 1
                continue
            }

            if isTableRow(cleaned),
               index + 1 < lines.count,
               let alignments = parseTableSeparator(lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)) {
                let headers = parseTableCells(cleaned)
                var rows: [[String]] = []
                var cursor = index + 2
                while cursor < lines.count {
                    let next = lines[cursor].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !isTableRow(next) { break }
                    rows.append(parseTableCells(next))
                    cursor += 1
                }
                let columnCount = max(headers.count, alignments.count)
                let normalized = padAlignments(alignments, to: columnCount)
                blocks.append(.table(headers: headers, rows: rows, alignments: normalized))
                index = cursor
                continue
            }

            if let image = MarkdownImage.parse(cleaned) {
                blocks.append(.image(image))
            } else if cleaned.hasPrefix("### ") {
                blocks.append(.heading(String(cleaned.dropFirst(4)), level: 3))
            } else if cleaned.hasPrefix("## ") {
                blocks.append(.heading(String(cleaned.dropFirst(3)), level: 2))
            } else if cleaned.hasPrefix("# ") {
                blocks.append(.heading(String(cleaned.dropFirst(2)), level: 1))
            } else if let todo = parseTodo(cleaned, lineIndex: index) {
                blocks.append(todo)
            } else if cleaned == "---" || cleaned == "***" || cleaned == "___" {
                blocks.append(.divider)
            } else if cleaned.hasPrefix("> ") {
                blocks.append(.quote(String(cleaned.dropFirst(2))))
            } else if cleaned.hasPrefix("- ") || cleaned.hasPrefix("* ") {
                blocks.append(.bullet(String(cleaned.dropFirst(2))))
            } else {
                blocks.append(.paragraph(cleaned))
            }
            index += 1
        }
        return blocks
    }

    private func parseTodo(_ line: String, lineIndex: Int) -> RenderedBlock? {
        guard let todo = MarkdownTodo.parse(line) else { return nil }
        return .todo(text: todo.text, checked: todo.checked, lineIndex: lineIndex)
    }

    private func isTableRow(_ line: String) -> Bool {
        line.hasPrefix("|") && line.hasSuffix("|") && line.count >= 2
    }

    private func parseTableCells(_ line: String) -> [String] {
        line.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func parseTableSeparator(_ line: String) -> [TableAlignment]? {
        guard isTableRow(line) else { return nil }
        let cells = parseTableCells(line)
        guard !cells.isEmpty else { return nil }
        var alignments: [TableAlignment] = []
        for cell in cells {
            let stripped = cell.trimmingCharacters(in: .whitespaces)
            let dashChars = stripped.filter { $0 == "-" || $0 == ":" }
            guard dashChars.count == stripped.count, stripped.contains("-") else { return nil }
            switch (stripped.hasPrefix(":"), stripped.hasSuffix(":")) {
            case (true, true): alignments.append(.center)
            case (false, true): alignments.append(.trailing)
            default: alignments.append(.leading)
            }
        }
        return alignments
    }

    private func padAlignments(_ alignments: [TableAlignment], to count: Int) -> [TableAlignment] {
        alignments.count >= count
            ? alignments
            : alignments + Array(repeating: .leading, count: count - alignments.count)
    }

    // MARK: - Rendering

    @ViewBuilder
    private func blockView(_ block: RenderedBlock) -> some View {
        switch block {
        case .heading(let value, let level):
            Text(inlineMarkdown(value))
                .font(headingFont(for: level))
                .fontWeight(.semibold)
                .lineSpacing(2 + textSizeOffset * 0.35)
                .padding(.top, level == 1 ? 2 : 8)
        case .paragraph(let value):
            Text(inlineMarkdown(value))
                .font(.system(size: bodyTextSize))
                .lineSpacing(bodyLineSpacing)
        case .bullet(let value):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                    .font(.system(size: bodyTextSize))
                    .foregroundStyle(.secondary)
                Text(inlineMarkdown(value))
                    .font(.system(size: bodyTextSize))
                    .lineSpacing(bodyLineSpacing)
            }
            .padding(.bottom, bulletBottomPadding)
        case .todo(let value, let checked, let lineIndex):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button {
                    toggleTodo(at: lineIndex)
                } label: {
                    Image(systemName: checked ? "checkmark.square.fill" : "square")
                        .font(.system(size: bodyTextSize + 2))
                        .foregroundStyle(checked ? accent.color : Color.secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .help(checked ? "Mark as not done" : "Mark as done")

                Text(inlineMarkdown(value))
                    .font(.system(size: bodyTextSize))
                    .strikethrough(checked, color: .secondary)
                    .foregroundStyle(checked ? .secondary : .primary)
                    .lineSpacing(bodyLineSpacing)
            }
            .padding(.bottom, bulletBottomPadding)
        case .quote(let value):
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accent.color.opacity(0.6))
                    .frame(width: 3)
                Text(inlineMarkdown(value))
                    .font(.system(size: bodyTextSize).italic())
                    .foregroundStyle(.secondary)
                    .lineSpacing(bodyLineSpacing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .divider:
            Divider().padding(.vertical, 6)
        case .table(let headers, let rows, let alignments):
            MarkdownTableView(
                headers: headers,
                rows: rows,
                alignments: alignments,
                fontSize: bodyTextSize
            )
        case .image(let image):
            NoteImageView(image: image)
        case .space:
            Spacer().frame(height: 2)
        }
    }

    // MARK: - Mutation

    private func toggleTodo(at lineIndex: Int) {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lineIndex >= 0, lineIndex < lines.count else { return }
        let original = lines[lineIndex]
        let leading = original.prefix { $0 == " " || $0 == "\t" }
        let trimmed = String(original.dropFirst(leading.count))

        guard let updated = MarkdownTodo.toggledBody(trimmed) else { return }

        lines[lineIndex] = String(leading) + updated
        text = lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private var textSizeOffset: CGFloat { CGFloat(textSizeStep) * 2 }
    private var bodyTextSize: CGFloat { 16 + textSizeOffset }
    private var bodyLineSpacing: CGFloat { 5 + textSizeOffset * 0.45 }
    private var bulletBottomPadding: CGFloat { 6 + textSizeOffset * 0.25 }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: .system(size: 28 + textSizeOffset)
        case 2: .system(size: 22 + textSizeOffset)
        default: .system(size: 18 + textSizeOffset)
        }
    }

    private func inlineMarkdown(_ value: String) -> AttributedString {
        (try? AttributedString(markdown: value)) ?? AttributedString(value)
    }
}

enum RenderedBlock {
    case heading(String, level: Int)
    case paragraph(String)
    case bullet(String)
    case todo(text: String, checked: Bool, lineIndex: Int)
    case quote(String)
    case divider
    case table(headers: [String], rows: [[String]], alignments: [TableAlignment])
    case image(MarkdownImage)
    case space
}

struct MarkdownTodo {
    struct Match {
        let text: String
        let checked: Bool
    }

    private struct MarkerMatch {
        let checked: Bool
        let text: String
        let checkboxRange: Range<String.Index>
    }

    private static let checkboxMarkers: [(marker: String, checked: Bool)] = [
        ("[ ]", false),
        ("[x]", true),
        ("[X]", true)
    ]

    private static let listPrefixes = ["", "- ", "* ", ". ", "• "]

    static func parse(_ line: String) -> Match? {
        guard let match = markerMatch(in: line) else { return nil }
        return Match(text: match.text, checked: match.checked)
    }

    static func toggledBody(_ body: String) -> String? {
        guard let match = markerMatch(in: body) else { return nil }
        var updated = body
        updated.replaceSubrange(match.checkboxRange, with: match.checked ? "[ ]" : "[x]")
        return updated
    }

    private static func markerMatch(in line: String) -> MarkerMatch? {
        for prefix in listPrefixes {
            if let match = markerMatch(in: line, after: prefix) {
                return match
            }
        }

        if let prefix = orderedListPrefix(in: line),
           let match = markerMatch(in: line, after: prefix) {
            return match
        }

        return nil
    }

    private static func markerMatch(in line: String, after prefix: String) -> MarkerMatch? {
        guard line.hasPrefix(prefix) else { return nil }
        let checkboxStart = line.index(line.startIndex, offsetBy: prefix.count)

        for checkbox in checkboxMarkers {
            guard line[checkboxStart...].hasPrefix(checkbox.marker) else { continue }
            let checkboxEnd = line.index(checkboxStart, offsetBy: checkbox.marker.count)
            if checkboxEnd == line.endIndex {
                return MarkerMatch(
                    checked: checkbox.checked,
                    text: "",
                    checkboxRange: checkboxStart..<checkboxEnd
                )
            }

            guard line[checkboxEnd] == " " else { continue }
            let textStart = line.index(after: checkboxEnd)
            return MarkerMatch(
                checked: checkbox.checked,
                text: String(line[textStart...]),
                checkboxRange: checkboxStart..<checkboxEnd
            )
        }

        return nil
    }

    private static func orderedListPrefix(in line: String) -> String? {
        var cursor = line.startIndex
        var hasDigit = false

        while cursor < line.endIndex, line[cursor].isNumber {
            hasDigit = true
            cursor = line.index(after: cursor)
        }

        guard hasDigit, cursor < line.endIndex else { return nil }
        let delimiter = line[cursor]
        guard delimiter == "." || delimiter == ")" else { return nil }

        let afterDelimiter = line.index(after: cursor)
        guard afterDelimiter < line.endIndex, line[afterDelimiter] == " " else { return nil }
        return String(line[...afterDelimiter])
    }
}
