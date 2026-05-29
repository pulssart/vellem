import SwiftUI

struct MobileMarkdownRenderedView: View {
    let text: String

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 7) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    blockView(block)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var blocks: [MobileMarkdownBlock] {
        MobileMarkdownParser(text: text).parse()
    }

    @ViewBuilder
    private func blockView(_ block: MobileMarkdownBlock) -> some View {
        switch block {
        case .heading(let value, let level):
            Text(inlineMarkdown(value))
                .font(headingFont(for: level))
                .fontWeight(.semibold)
                .lineSpacing(3)
                .padding(.top, level == 1 ? 0 : 8)
        case .paragraph(let value):
            Text(inlineMarkdown(value))
                .font(.body)
                .lineSpacing(5)
        case .bullet(let value):
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text("•")
                    .foregroundStyle(.secondary)
                Text(inlineMarkdown(value))
                    .lineSpacing(5)
            }
        case .ordered(let marker, let value):
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(marker)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 26, alignment: .trailing)
                Text(inlineMarkdown(value))
                    .lineSpacing(5)
            }
        case .todo(let value, let checked):
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(checked ? .green : .secondary)
                Text(inlineMarkdown(value))
                    .strikethrough(checked, color: .secondary)
                    .foregroundStyle(checked ? .secondary : .primary)
                    .lineSpacing(5)
            }
        case .quote(let value):
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 3)
                Text(inlineMarkdown(value))
                    .font(.body.italic())
                    .foregroundStyle(.secondary)
                    .lineSpacing(5)
            }
            .padding(.vertical, 4)
        case .divider:
            Divider()
                .padding(.vertical, 8)
        case .code(let value, let language):
            VStack(alignment: .leading, spacing: 8) {
                if let language {
                    Text(language.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: true) {
                    Text(value.isEmpty ? " " : value)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                }
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(uiColor: .separator), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.vertical, 5)
        case .table(let headers, let rows, let alignments):
            MobileMarkdownTableView(headers: headers, rows: rows, alignments: alignments)
        case .image(let image):
            MobileMarkdownImageView(image: image)
        case .space:
            Spacer().frame(height: 4)
        }
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: .title2
        case 2: .title3
        case 3: .headline
        default: .subheadline.weight(.semibold)
        }
    }

    private func inlineMarkdown(_ value: String) -> AttributedString {
        (try? AttributedString(markdown: value, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(value)
    }
}

private struct MobileMarkdownParser {
    let text: String

    func parse() -> [MobileMarkdownBlock] {
        var blocks: [MobileMarkdownBlock] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var index = 0

        while index < lines.count {
            let cleaned = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)

            if cleaned.isEmpty {
                blocks.append(.space)
                index += 1
                continue
            }

            if let fence = codeFenceMarker(in: cleaned) {
                let language = cleaned.dropFirst(fence.count).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                var cursor = index + 1
                while cursor < lines.count {
                    let next = lines[cursor]
                    if next.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(fence) {
                        cursor += 1
                        break
                    }
                    codeLines.append(next)
                    cursor += 1
                }
                blocks.append(.code(codeLines.joined(separator: "\n"), language: language.isEmpty ? nil : language))
                index = cursor
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
                blocks.append(.table(headers: headers, rows: rows, alignments: padAlignments(alignments, to: max(headers.count, alignments.count))))
                index = cursor
                continue
            }

            if let image = MobileMarkdownImage.parse(cleaned) {
                blocks.append(.image(image))
            } else if let heading = parseHeading(cleaned) {
                blocks.append(.heading(heading.text, level: heading.level))
            } else if let todo = MobileMarkdownTodo.parse(cleaned) {
                blocks.append(.todo(text: todo.text, checked: todo.checked))
            } else if cleaned == "---" || cleaned == "***" || cleaned == "___" {
                blocks.append(.divider)
            } else if isQuoteLine(cleaned) {
                var quoteLines: [String] = []
                var cursor = index
                while cursor < lines.count {
                    let next = lines[cursor].trimmingCharacters(in: .whitespacesAndNewlines)
                    guard isQuoteLine(next) else { break }
                    quoteLines.append(next == ">" ? "" : String(next.dropFirst(2)))
                    cursor += 1
                }
                blocks.append(.quote(quoteLines.joined(separator: "\n")))
                index = cursor
                continue
            } else if cleaned.hasPrefix("- ") || cleaned.hasPrefix("* ") {
                blocks.append(.bullet(String(cleaned.dropFirst(2))))
            } else if let ordered = parseOrderedList(cleaned) {
                blocks.append(.ordered(marker: ordered.marker, text: ordered.text))
            } else {
                blocks.append(.paragraph(cleaned))
            }

            index += 1
        }

        return blocks
    }

    private func codeFenceMarker(in line: String) -> String? {
        if line.hasPrefix("```") { return "```" }
        if line.hasPrefix("~~~") { return "~~~" }
        return nil
    }

    private func parseHeading(_ line: String) -> (level: Int, text: String)? {
        var level = 0
        for character in line {
            guard character == "#" else { break }
            level += 1
        }
        guard (1...6).contains(level),
              line.count > level,
              line[line.index(line.startIndex, offsetBy: level)] == " " else {
            return nil
        }
        return (level, String(line.dropFirst(level + 1)))
    }

    private func isQuoteLine(_ line: String) -> Bool {
        line == ">" || line.hasPrefix("> ")
    }

    private func parseOrderedList(_ line: String) -> (marker: String, text: String)? {
        guard let marker = orderedListMarker(in: line) else { return nil }
        return (marker.trimmingCharacters(in: .whitespaces), String(line.dropFirst(marker.count)))
    }

    private func orderedListMarker(in line: String) -> String? {
        var cursor = line.startIndex
        var hasDigit = false
        while cursor < line.endIndex, line[cursor].isNumber {
            hasDigit = true
            cursor = line.index(after: cursor)
        }
        guard hasDigit, cursor < line.endIndex else { return nil }
        guard line[cursor] == "." || line[cursor] == ")" else { return nil }
        let afterDelimiter = line.index(after: cursor)
        guard afterDelimiter < line.endIndex, line[afterDelimiter] == " " else { return nil }
        return String(line[...afterDelimiter])
    }

    private func isTableRow(_ line: String) -> Bool {
        line.hasPrefix("|") && line.hasSuffix("|") && line.count >= 2
    }

    private func parseTableCells(_ line: String) -> [String] {
        line.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func parseTableSeparator(_ line: String) -> [MobileTableAlignment]? {
        guard isTableRow(line) else { return nil }
        let cells = parseTableCells(line)
        guard !cells.isEmpty else { return nil }
        var alignments: [MobileTableAlignment] = []
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

    private func padAlignments(_ alignments: [MobileTableAlignment], to count: Int) -> [MobileTableAlignment] {
        alignments.count >= count
            ? alignments
            : alignments + Array(repeating: .leading, count: count - alignments.count)
    }
}

private enum MobileMarkdownBlock {
    case heading(String, level: Int)
    case paragraph(String)
    case bullet(String)
    case ordered(marker: String, text: String)
    case todo(text: String, checked: Bool)
    case quote(String)
    case divider
    case code(String, language: String?)
    case table(headers: [String], rows: [[String]], alignments: [MobileTableAlignment])
    case image(MobileMarkdownImage)
    case space
}

private struct MobileMarkdownTodo {
    let text: String
    let checked: Bool

    static func parse(_ line: String) -> MobileMarkdownTodo? {
        for prefix in ["- ", "* ", ""] {
            guard line.hasPrefix(prefix) else { continue }
            let body = String(line.dropFirst(prefix.count))
            if body.hasPrefix("[ ] ") {
                return MobileMarkdownTodo(text: String(body.dropFirst(4)), checked: false)
            }
            if body.hasPrefix("[x] ") || body.hasPrefix("[X] ") {
                return MobileMarkdownTodo(text: String(body.dropFirst(4)), checked: true)
            }
        }
        return nil
    }
}

private struct MobileMarkdownImage: Hashable {
    let alt: String
    let url: URL

    static func parse(_ line: String) -> MobileMarkdownImage? {
        guard line.hasPrefix("!["),
              let closeAlt = line.firstIndex(of: "]"),
              line[line.index(after: closeAlt)...].hasPrefix("("),
              line.hasSuffix(")") else {
            return nil
        }

        let alt = String(line[line.index(line.startIndex, offsetBy: 2)..<closeAlt])
        let urlStart = line.index(closeAlt, offsetBy: 2)
        let urlEnd = line.index(before: line.endIndex)
        guard urlStart < urlEnd,
              let url = URL(string: String(line[urlStart..<urlEnd])) else {
            return nil
        }

        return MobileMarkdownImage(alt: alt, url: url)
    }
}

private struct MobileMarkdownImageView: View {
    let image: MobileMarkdownImage

    var body: some View {
        AsyncImage(url: image.url) { phase in
            switch phase {
            case .success(let resolved):
                resolved
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            case .failure:
                Label("Image indisponible", systemImage: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            default:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .accessibilityLabel(image.alt)
        .padding(.vertical, 6)
    }
}

private struct MobileMarkdownTableView: View {
    let headers: [String]
    let rows: [[String]]
    let alignments: [MobileTableAlignment]

    private var columnCount: Int {
        max(headers.count, rows.map(\.count).max() ?? 0)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                row(headers, isHeader: true, isAlternate: false)
                Divider()
                ForEach(Array(rows.enumerated()), id: \.offset) { offset, values in
                    row(values, isHeader: false, isAlternate: offset.isMultiple(of: 2))
                    if offset < rows.count - 1 {
                        Divider().opacity(0.45)
                    }
                }
            }
            .background(Color(uiColor: .systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color(uiColor: .separator), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .padding(.vertical, 5)
    }

    private func row(_ values: [String], isHeader: Bool, isAlternate: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<columnCount, id: \.self) { column in
                cell(
                    values.indices.contains(column) ? values[column] : "",
                    alignment: alignments.indices.contains(column) ? alignments[column] : .leading,
                    isHeader: isHeader
                )
                if column < columnCount - 1 {
                    Rectangle()
                        .fill(Color(uiColor: .separator).opacity(0.45))
                        .frame(width: 1)
                }
            }
        }
        .background(isHeader ? Color(uiColor: .secondarySystemBackground) : (isAlternate ? Color.clear : Color(uiColor: .secondarySystemBackground).opacity(0.45)))
    }

    private func cell(_ value: String, alignment: MobileTableAlignment, isHeader: Bool) -> some View {
        Text((try? AttributedString(markdown: value, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(value))
            .font(.system(size: 14, weight: isHeader ? .semibold : .regular))
            .multilineTextAlignment(alignment.textAlignment)
            .frame(minWidth: 86, alignment: alignment.frameAlignment)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
    }
}

private enum MobileTableAlignment {
    case leading, center, trailing

    var textAlignment: TextAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}
