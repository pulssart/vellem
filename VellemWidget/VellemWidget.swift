import SwiftUI
import WidgetKit

private let widgetHeaderColor = Color(nsColor: .systemYellow).opacity(0.30)

struct WidgetNote: Identifiable, Codable {
    var id: UUID
    var text: String
    var generatedTitle: String? = nil
    var createdAt: Date
    var updatedAt: Date

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
        text.vellemDisplayText
    }
}

private extension String {
    var vellemDisplayText: String {
        var cleaned = self
            .replacing(/\!\[([^\]]*)\]\([^)]+\)/, with: "$1")
            .replacing(/\[([^\]]+)\]\([^)]+\)/, with: "$1")
            .replacing(/(?m)^\s{0,3}#{1,6}\s*/, with: "")
            .replacing(/(?m)^\s{0,3}>\s*/, with: "")
            .replacing(/(?m)^\s*[-*+]\s+/, with: "")
            .replacing(/(?m)^\s*\d+[.)]\s+/, with: "")
            .replacingOccurrences(of: "\n", with: " ")

        for marker in ["**", "__", "~~", "`", "*", "_", "#"] {
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }

        return cleaned
            .replacing(/\s+/, with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct VellemEntry: TimelineEntry {
    let date: Date
    let notes: [WidgetNote]
    let status: String?
}

struct VellemProvider: TimelineProvider {
    func placeholder(in context: Context) -> VellemEntry {
        VellemEntry(date: .now, notes: [
            WidgetNote(id: UUID(), text: "Capture the thought before it evaporates.", createdAt: .now, updatedAt: .now)
        ], status: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (VellemEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VellemEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .after(.now.addingTimeInterval(30))))
    }

    private func entry() -> VellemEntry {
        let url: URL
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "MKAFV9VL9V.com.adriendonot.Vellem") {
            url = container.appending(path: "notes.json")
        } else {
            url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appending(path: "Vellem/notes.json")
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return VellemEntry(date: .now, notes: [], status: "Missing notes file")
        }

        guard let data = try? Data(contentsOf: url) else {
            return VellemEntry(date: .now, notes: [], status: "Can't read notes")
        }

        guard let notes = try? JSONDecoder().decode([WidgetNote].self, from: data) else {
            return VellemEntry(date: .now, notes: [], status: "Can't decode notes")
        }

        let visibleNotes = Array(notes
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(8))
        return VellemEntry(date: .now, notes: visibleNotes, status: visibleNotes.isEmpty ? "No notes yet." : nil)
    }
}

struct VellemWidgetView: View {
    var entry: VellemEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            content
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 14)
                .padding(.bottom, 18)
        }
        .containerBackground(.background, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            if entry.notes.isEmpty {
                Text(entry.status ?? "No notes yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            } else if family == .systemExtraLarge {
                LazyVGrid(columns: extraLargeColumns, alignment: .leading, spacing: 14) {
                    ForEach(entry.notes.prefix(noteLimit)) { note in
                        WidgetNoteRow(note: note, previewLineLimit: previewLineLimit)
                    }
                }
                Spacer(minLength: 0)
            } else {
                ForEach(entry.notes.prefix(noteLimit)) { note in
                    WidgetNoteRow(note: note, previewLineLimit: previewLineLimit)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Vellem")
                .font(.headline)
            Spacer()
            Link(destination: URL(string: "vellem://new")!) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
            }
        }
        .padding(.horizontal, horizontalPadding)
        .frame(height: headerHeight)
        .background(widgetHeaderColor)
    }

    private var horizontalPadding: CGFloat {
        family == .systemSmall ? 20 : 22
    }

    private var headerHeight: CGFloat {
        family == .systemSmall ? 44 : 48
    }

    private var contentSpacing: CGFloat {
        isLargeFamily ? 14 : 12
    }

    private var extraLargeColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 22, alignment: .topLeading),
            GridItem(.flexible(), spacing: 22, alignment: .topLeading)
        ]
    }

    private var noteLimit: Int {
        switch family {
        case .systemSmall:
            1
        case .systemExtraLarge:
            8
        case .systemLarge:
            6
        default:
            2
        }
    }

    private var previewLineLimit: Int {
        isLargeFamily ? 2 : 1
    }

    private var isLargeFamily: Bool {
        family == .systemLarge || family == .systemExtraLarge
    }
}

private struct WidgetNoteRow: View {
    let note: WidgetNote
    let previewLineLimit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(note.title)
                .font(.callout)
                .fontWeight(.medium)
                .lineLimit(1)
            Text(note.preview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(previewLineLimit)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct VellemWidget: Widget {
    let kind = "VellemWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VellemProvider()) { entry in
            VellemWidgetView(entry: entry)
        }
        .configurationDisplayName("Vellem")
        .description("Recent notes and one-tap capture.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

struct VellemLargeWidget: Widget {
    let kind = "VellemLargeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VellemProvider()) { entry in
            VellemWidgetView(entry: entry)
        }
        .configurationDisplayName("Vellem Large")
        .description("More recent notes in a larger view.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

@main
struct VellemWidgetBundle: WidgetBundle {
    var body: some Widget {
        VellemWidget()
        VellemLargeWidget()
    }
}
