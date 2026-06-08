import AppKit
import SwiftUI

struct MarkdownTableView: View {
    let headers: [String]
    let rows: [[String]]
    let alignments: [TableAlignment]
    let fontSize: CGFloat

    private var columnCount: Int {
        max(headers.count, rows.map(\.count).max() ?? 0)
    }

    private var tableHeight: CGFloat {
        guard columnCount > 0 else { return 0 }
        let rowHeight: CGFloat = 29
        let headerHeight: CGFloat = 28
        return headerHeight + (CGFloat(rows.count) * rowHeight) + 2
    }

    var body: some View {
        MarkdownTableRepresentable(
            headers: headers,
            rows: rows,
            alignments: alignments,
            fontSize: fontSize
        )
        .frame(height: tableHeight)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .padding(.vertical, 4)
    }
}

private struct MarkdownTableRepresentable: NSViewRepresentable {
    let headers: [String]
    let rows: [[String]]
    let alignments: [TableAlignment]
    let fontSize: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let tableView = MarkdownNSTableView()
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.headerView = NSTableHeaderView()
        tableView.rowHeight = 29
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.backgroundColor = .textBackgroundColor
        tableView.gridStyleMask = [.solidHorizontalGridLineMask, .solidVerticalGridLineMask]
        tableView.gridColor = .separatorColor.withAlphaComponent(0.45)
        tableView.allowsColumnResizing = true
        tableView.allowsColumnReordering = false
        tableView.allowsColumnSelection = false
        tableView.allowsMultipleSelection = false
        tableView.selectionHighlightStyle = .none
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        tableView.style = .plain

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        context.coordinator.tableView = tableView
        context.coordinator.configure(headers: headers, rows: rows, alignments: alignments, fontSize: fontSize)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tableView = scrollView.documentView as? NSTableView else { return }
        context.coordinator.tableView = tableView
        context.coordinator.configure(headers: headers, rows: rows, alignments: alignments, fontSize: fontSize)
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        weak var tableView: NSTableView?
        private var headers: [String] = []
        private var rows: [[String]] = []
        private var alignments: [TableAlignment] = []
        private var fontSize: CGFloat = 15
        private var contentSignature = ""
        private var isApplyingColumnWidths = false
        private let horizontalPadding: CGFloat = 34
        private let minColumnWidth: CGFloat = 70
        private let maxColumnWidth: CGFloat = 620

        private var columnCount: Int {
            max(headers.count, rows.map(\.count).max() ?? 0)
        }

        func configure(headers: [String], rows: [[String]], alignments: [TableAlignment], fontSize: CGFloat) {
            self.headers = headers
            self.rows = rows
            self.alignments = alignments
            self.fontSize = fontSize

            guard let tableView else { return }
            let nextSignature = signature(headers: headers, rows: rows, fontSize: fontSize)
            let didRebuildColumns = rebuildColumnsIfNeeded(in: tableView)
            if didRebuildColumns || nextSignature != contentSignature {
                contentSignature = nextSignature
                applyColumnWidths(in: tableView, signature: nextSignature)
            }
            tableView.reloadData()
            tableView.needsLayout = true
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            rows.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let tableColumn, let column = Int(tableColumn.identifier.rawValue) else { return nil }
            let identifier = NSUserInterfaceItemIdentifier("MarkdownTableCell")
            let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? MarkdownTableCellView
                ?? MarkdownTableCellView(identifier: identifier)
            let value = column < rows[row].count ? rows[row][column] : ""
            cell.configure(
                text: value,
                alignment: alignment(for: column).naturalTextAlignment,
                font: .systemFont(ofSize: max(12, fontSize - 1), weight: .regular),
                isHeader: false
            )
            return cell
        }

        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            MarkdownTableRowView(isAlternate: !row.isMultiple(of: 2))
        }

        func tableViewColumnDidResize(_ notification: Notification) {
            guard !isApplyingColumnWidths,
                  !contentSignature.isEmpty,
                  let tableView = notification.object as? NSTableView
            else { return }

            saveColumnWidths(from: tableView, signature: contentSignature)
            updateFrame(for: tableView)
        }

        private func rebuildColumnsIfNeeded(in tableView: NSTableView) -> Bool {
            let existing = tableView.tableColumns.map { $0.identifier.rawValue }
            let expected = (0..<columnCount).map(String.init)
            guard existing != expected else { return false }

            for tableColumn in tableView.tableColumns {
                tableView.removeTableColumn(tableColumn)
            }
            for column in 0..<columnCount {
                let identifier = NSUserInterfaceItemIdentifier(String(column))
                let tableColumn = NSTableColumn(identifier: identifier)
                tableColumn.title = column < headers.count ? headers[column] : ""
                tableColumn.headerCell = MarkdownTableHeaderCell(textCell: tableColumn.title)
                tableColumn.resizingMask = [.userResizingMask]
                tableColumn.minWidth = minColumnWidth
                tableColumn.maxWidth = maxColumnWidth
                tableView.addTableColumn(tableColumn)
            }
            return true
        }

        private func applyColumnWidths(in tableView: NSTableView, signature: String) {
            let storedWidths = storedColumnWidths(for: signature)
            isApplyingColumnWidths = true
            defer { isApplyingColumnWidths = false }

            for column in 0..<columnCount {
                guard column < tableView.tableColumns.count else { continue }
                let tableColumn = tableView.tableColumns[column]
                let storedWidth = storedWidths?[safe: column].map { CGFloat($0) }
                let width = storedWidth ?? measuredWidth(for: column)
                let clampedWidth = min(max(width, minColumnWidth), maxColumnWidth)
                if abs(tableColumn.width - clampedWidth) > 1 {
                    tableColumn.width = clampedWidth
                }
            }

            updateFrame(for: tableView)
        }

        private func updateFrame(for tableView: NSTableView) {
            let totalWidth = tableView.tableColumns.reduce(CGFloat(0)) { $0 + $1.width }
            tableView.frame.size = NSSize(
                width: max(totalWidth, tableView.enclosingScrollView?.contentSize.width ?? totalWidth),
                height: tableView.intrinsicContentSize.height
            )
        }

        private func measuredWidth(for column: Int) -> CGFloat {
            var width = textWidth(headers[safe: column] ?? "", font: .systemFont(ofSize: fontSize, weight: .semibold))
            for row in rows {
                width = max(width, textWidth(row[safe: column] ?? "", font: .systemFont(ofSize: max(12, fontSize - 1))))
            }
            return min(max(width + horizontalPadding, minColumnWidth), maxColumnWidth)
        }

        private func textWidth(_ value: String, font: NSFont) -> CGFloat {
            let plain = value.replacingOccurrences(of: #"[*_`~]"#, with: "", options: .regularExpression)
            return NSString(string: plain).size(withAttributes: [.font: font]).width
        }

        private func alignment(for column: Int) -> TableAlignment {
            column < alignments.count ? alignments[column] : .leading
        }

        private func signature(headers: [String], rows: [[String]], fontSize: CGFloat) -> String {
            ([headers.joined(separator: "\u{1f}")] + rows.map { $0.joined(separator: "\u{1f}") }).joined(separator: "\u{1e}") + ":\(fontSize)"
        }

        private func storedColumnWidths(for signature: String) -> [Double]? {
            guard let widths = UserDefaults.standard.array(forKey: persistenceKey(for: signature)) as? [Double],
                  widths.count == columnCount
            else { return nil }
            return widths
        }

        private func saveColumnWidths(from tableView: NSTableView, signature: String) {
            let widths = tableView.tableColumns.map(\.width).map(Double.init)
            guard widths.count == columnCount else { return }
            UserDefaults.standard.set(widths, forKey: persistenceKey(for: signature))
        }

        private func persistenceKey(for signature: String) -> String {
            var hash: UInt64 = 14695981039346656037
            for byte in signature.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 1099511628211
            }
            return "MarkdownTableColumnWidths.\(String(hash, radix: 16))"
        }
    }
}

private final class MarkdownNSTableView: NSTableView {
    override var intrinsicContentSize: NSSize {
        let width = tableColumns.reduce(CGFloat(0)) { $0 + $1.width }
        let headerHeight = headerView?.frame.height ?? 0
        let height = headerHeight + CGFloat(numberOfRows) * rowHeight
        return NSSize(width: width, height: height)
    }
}

private final class MarkdownTableCellView: NSTableCellView {
    private let label = NSTextField(labelWithString: "")

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 11),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -11),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(text: String, alignment: NSTextAlignment, font: NSFont, isHeader: Bool) {
        label.attributedStringValue = inlineMarkdown(text, font: font, isHeader: isHeader)
        label.alignment = alignment
        label.textColor = .labelColor
    }

    private func inlineMarkdown(_ value: String, font: NSFont, isHeader: Bool) -> NSAttributedString {
        let fallback = NSAttributedString(
            string: value,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]
        )
        guard let attributed = try? AttributedString(
            markdown: value,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return fallback
        }

        let result = NSMutableAttributedString(attributedString: NSAttributedString(attributed))
        let range = NSRange(location: 0, length: result.length)
        result.addAttributes([
            .font: font,
            .foregroundColor: NSColor.labelColor
        ], range: range)
        if isHeader {
            result.addAttribute(.font, value: font, range: range)
        }
        return result
    }
}

private final class MarkdownTableHeaderCell: NSTableHeaderCell {
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        NSColor.appAccent.withAlphaComponent(0.18).setFill()
        cellFrame.fill()
        super.draw(withFrame: cellFrame.insetBy(dx: 6, dy: 0), in: controlView)
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        attributedStringValue = NSAttributedString(
            string: stringValue,
            attributes: [
                .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: style
            ]
        )
        super.drawInterior(withFrame: cellFrame.insetBy(dx: 5, dy: 0), in: controlView)
    }
}

private final class MarkdownTableRowView: NSTableRowView {
    private let isAlternate: Bool

    init(isAlternate: Bool) {
        self.isAlternate = isAlternate
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func drawBackground(in dirtyRect: NSRect) {
        if isAlternate {
            NSColor.controlBackgroundColor.withAlphaComponent(0.5).setFill()
            dirtyRect.fill()
        }
    }
}

private extension TableAlignment {
    var naturalTextAlignment: NSTextAlignment {
        switch self {
        case .leading: .left
        case .center: .center
        case .trailing: .right
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
