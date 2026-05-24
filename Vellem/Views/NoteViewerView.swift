import AppKit
import SwiftUI

struct NoteViewerView: View {
    @ObservedObject var store: NotesStore
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var copyFeedback: String?
    @State private var textSizeStep = 0

    var body: some View {
        Group {
            if let note = store.viewerNote {
                content(for: note)
            } else {
                emptyState
            }
        }
        .frame(minWidth: 320, idealWidth: 560, maxWidth: .infinity, minHeight: 240, idealHeight: 600, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .background(NoteViewerWindowConfigurator())
    }

    private func content(for note: Note) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(for: note)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(blocks(for: note.text).enumerated()), id: \.offset) { _, block in
                        blockView(block, for: note)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .textSelection(.enabled)

            footer(for: note)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No note selected")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func header(for note: Note) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(note.updatedAt, style: .relative)
                    Text("·")
                    Text("\(note.wordCount) words")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 0) {
                Button {
                    textSizeStep = max(0, textSizeStep - 1)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 20)
                }
                .disabled(textSizeStep == 0)
                .help("Decrease text size")

                Button {
                    textSizeStep = min(8, textSizeStep + 1)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 20)
                }
                .disabled(textSizeStep == 8)
                .help("Increase text size")
            }
            .buttonStyle(.borderless)

            Button {
                copy(note.text)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy note")

            Button {
                dismissWindow(id: "note-viewer")
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.cancelAction)
            .help("Close")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(Color(nsColor: .systemYellow).opacity(0.42))
    }

    private func footer(for note: Note) -> some View {
        HStack {
            if let copyFeedback {
                Text(copyFeedback)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let sourceDescription = sourceDescription(for: note) {
                Label(sourceDescription, systemImage: note.sourceURL == nil ? "app" : "link")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func sourceDescription(for note: Note) -> String? {
        switch (note.sourceApp, note.sourceURL) {
        case let (sourceApp?, sourceURL?):
            "\(sourceApp), \(sourceURL.absoluteString)"
        case let (sourceApp?, nil):
            sourceApp
        case let (nil, sourceURL?):
            sourceURL.absoluteString
        case (nil, nil):
            nil
        }
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        copyFeedback = "Copied."
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copyFeedback = nil
        }
    }

    private func blocks(for text: String) -> [ViewerBlock] {
        var blocks: [ViewerBlock] = []
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

            // Table: header row + separator row + N data rows
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
                let normalizedAlignments = padAlignments(alignments, to: columnCount)
                blocks.append(.table(headers: headers, rows: rows, alignments: normalizedAlignments))
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
            } else if cleaned.hasPrefix("- ") || cleaned.hasPrefix("* ") {
                blocks.append(.bullet(String(cleaned.dropFirst(2))))
            } else {
                blocks.append(.paragraph(cleaned))
            }
            index += 1
        }
        return blocks
    }

    // MARK: - Tables

    private func isTableRow(_ line: String) -> Bool {
        return line.hasPrefix("|") && line.hasSuffix("|") && line.count >= 2
    }

    private func parseTableCells(_ line: String) -> [String] {
        let trimmed = line
            .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
        return trimmed.split(separator: "|", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }

    private func parseTableSeparator(_ line: String) -> [TableAlignment]? {
        guard isTableRow(line) else { return nil }
        let cells = parseTableCells(line)
        guard !cells.isEmpty else { return nil }
        var alignments: [TableAlignment] = []
        for cell in cells {
            let stripped = cell.trimmingCharacters(in: .whitespaces)
            // Must look like ---, :---, ---:, :---:
            let dashChars = stripped.filter { $0 == "-" || $0 == ":" }
            guard dashChars.count == stripped.count, stripped.contains("-") else { return nil }
            let leadingColon = stripped.hasPrefix(":")
            let trailingColon = stripped.hasSuffix(":")
            switch (leadingColon, trailingColon) {
            case (true, true): alignments.append(.center)
            case (false, true): alignments.append(.trailing)
            case (true, false): alignments.append(.leading)
            case (false, false): alignments.append(.leading)
            }
        }
        return alignments
    }

    private func padAlignments(_ alignments: [TableAlignment], to count: Int) -> [TableAlignment] {
        if alignments.count >= count { return alignments }
        return alignments + Array(repeating: .leading, count: count - alignments.count)
    }

    private func parseTodo(_ line: String, lineIndex: Int) -> ViewerBlock? {
        guard let todo = MarkdownTodo.parse(line) else { return nil }
        return .todo(text: todo.text, checked: todo.checked, lineIndex: lineIndex)
    }

    private func toggleTodo(at lineIndex: Int, in note: Note) {
        var lines = note.text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lineIndex >= 0, lineIndex < lines.count else { return }
        let original = lines[lineIndex]
        let leading = original.prefix { $0 == " " || $0 == "\t" }
        let trimmed = String(original.dropFirst(leading.count))

        guard let updated = MarkdownTodo.toggledBody(trimmed) else { return }

        lines[lineIndex] = String(leading) + updated
        store.update(noteID: note.id, text: lines.joined(separator: "\n"))
    }

    @ViewBuilder
    private func blockView(_ block: ViewerBlock, for note: Note) -> some View {
        switch block {
        case .heading(let value, let level):
            Text(inlineMarkdown(value))
                .font(headingFont(for: level))
                .fontWeight(.semibold)
                .lineSpacing(2 + textSizeOffset * 0.35)
                .padding(.top, level == 1 ? 2 : 6)
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
                    toggleTodo(at: lineIndex, in: note)
                } label: {
                    Image(systemName: checked ? "checkmark.square.fill" : "square")
                        .font(.system(size: bodyTextSize + 2))
                        .foregroundStyle(checked ? Color(nsColor: .systemYellow) : Color.secondary)
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

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: .system(size: 28 + textSizeOffset)
        case 2: .system(size: 22 + textSizeOffset)
        default: .system(size: 18 + textSizeOffset)
        }
    }

    private var textSizeOffset: CGFloat {
        CGFloat(textSizeStep) * 2
    }

    private var bodyTextSize: CGFloat {
        16 + textSizeOffset
    }

    private var bodyLineSpacing: CGFloat {
        5 + textSizeOffset * 0.45
    }

    private var bulletBottomPadding: CGFloat {
        6 + textSizeOffset * 0.25
    }

    private func inlineMarkdown(_ value: String) -> AttributedString {
        (try? AttributedString(markdown: value)) ?? AttributedString(value)
    }
}

private enum ViewerBlock {
    case heading(String, level: Int)
    case paragraph(String)
    case bullet(String)
    case todo(text: String, checked: Bool, lineIndex: Int)
    case table(headers: [String], rows: [[String]], alignments: [TableAlignment])
    case image(MarkdownImage)
    case space
}

enum TableAlignment {
    case leading, center, trailing

    var horizontal: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

private struct NoteViewerWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(window: view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(window: nsView.window) }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.hidesOnDeactivate = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        window.hasShadow = true
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.insert(.resizable)
        window.titlebarSeparatorStyle = .none
        window.minSize = NSSize(width: 320, height: 240)
        alignToPixelGrid(window)
        window.orderFrontRegardless()
    }

    private func alignToPixelGrid(_ window: NSWindow) {
        let scale = window.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        var frame = window.frame
        frame.origin.x = (frame.origin.x * scale).rounded() / scale
        frame.origin.y = (frame.origin.y * scale).rounded() / scale
        frame.size.width = (frame.size.width * scale).rounded() / scale
        frame.size.height = (frame.size.height * scale).rounded() / scale

        if frame != window.frame {
            window.setFrame(frame, display: false)
        }
    }
}
