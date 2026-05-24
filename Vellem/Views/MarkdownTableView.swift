import SwiftUI

/// Lightweight markdown table renderer.
/// Wraps cells using a horizontally scrollable grid when the content overflows.
struct MarkdownTableView: View {
    let headers: [String]
    let rows: [[String]]
    let alignments: [TableAlignment]
    let fontSize: CGFloat

    private var columnCount: Int {
        max(headers.count, rows.map(\.count).max() ?? 0)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                Divider().background(Color(nsColor: .separatorColor))
                ForEach(Array(rows.enumerated()), id: \.offset) { offset, row in
                    dataRow(row, isAlternate: offset.isMultiple(of: 2))
                    if offset < rows.count - 1 {
                        Divider().opacity(0.4)
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(.vertical, 4)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(0..<columnCount, id: \.self) { col in
                cell(
                    text: col < headers.count ? headers[col] : "",
                    alignment: col < alignments.count ? alignments[col] : .leading,
                    isHeader: true
                )
                if col < columnCount - 1 {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor).opacity(0.5))
                        .frame(width: 1)
                }
            }
        }
        .background(Color(nsColor: .systemYellow).opacity(0.18))
    }

    private func dataRow(_ row: [String], isAlternate: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<columnCount, id: \.self) { col in
                cell(
                    text: col < row.count ? row[col] : "",
                    alignment: col < alignments.count ? alignments[col] : .leading,
                    isHeader: false
                )
                if col < columnCount - 1 {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor).opacity(0.3))
                        .frame(width: 1)
                }
            }
        }
        .background(isAlternate ? Color.clear : Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private func cell(text: String, alignment: TableAlignment, isHeader: Bool) -> some View {
        Text(inlineMarkdown(text))
            .font(.system(size: fontSize - (isHeader ? 0 : 1), weight: isHeader ? .semibold : .regular))
            .foregroundStyle(isHeader ? .primary : .primary)
            .multilineTextAlignment(alignment.textAlignment)
            .frame(minWidth: 70, alignment: alignment.frameAlignment)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
    }

    private func inlineMarkdown(_ value: String) -> AttributedString {
        (try? AttributedString(markdown: value)) ?? AttributedString(value)
    }
}
