import AppKit
import SwiftUI
import WidgetKit

private let widgetAppGroupID = "MKAFV9VL9V.com.adriendonot.Vellem"
private let widgetAccentStorageKey = "appAccentColor"

private func widgetAccentNSColor() -> NSColor {
    let raw = UserDefaults(suiteName: widgetAppGroupID)?.string(forKey: widgetAccentStorageKey)
        ?? UserDefaults.standard.string(forKey: widgetAccentStorageKey)
    switch raw {
    case "orange": return .systemOrange
    case "red":    return .systemRed
    case "pink":   return .systemPink
    case "purple": return .systemPurple
    case "blue":   return .systemBlue
    case "green":  return .systemGreen
    default:       return .systemYellow
    }
}

private var widgetHeaderColor: Color {
    Color(nsColor: widgetAccentNSColor()).opacity(0.30)
}

private extension URL {
    static let vellemNewNote = vellemDeepLink(host: "new")

    static func vellemNote(_ id: UUID) -> URL {
        vellemDeepLink(host: "note", path: "/\(id.uuidString)")
    }

    private static func vellemDeepLink(host: String, path: String = "") -> URL {
        var components = URLComponents()
        components.scheme = "vellem"
        components.host = host
        components.path = path
        return components.url ?? URL(fileURLWithPath: "/")
    }
}

struct WidgetNote: Identifiable, Codable {
    var id: UUID
    var text: String
    var generatedTitle: String? = nil
    var kind: WidgetNoteKind? = .regular
    var sourceApp: String? = nil
    var createdAt: Date
    var updatedAt: Date
    var folderID: UUID? = nil
    var provenance: String? = nil

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

enum WidgetNoteKind: String, Codable {
    case regular
    case daily
}

struct WidgetFolder: Identifiable, Codable {
    var id: UUID
    var name: String
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
        // The main app calls WidgetCenter.shared.reloadAllTimelines() after every save.
        // This policy is a background fallback for when the app isn't running.
        completion(Timeline(entries: [entry()], policy: .after(.now.addingTimeInterval(900))))
    }

    private func entry() -> VellemEntry {
        let notesURL: URL
        let foldersURL: URL
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "MKAFV9VL9V.com.adriendonot.Vellem") {
            notesURL = container.appending(path: "notes.json")
            foldersURL = container.appending(path: "folders.json")
        } else {
            let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appending(path: "Vellem")
            notesURL = supportURL.appending(path: "notes.json")
            foldersURL = supportURL.appending(path: "folders.json")
        }

        guard FileManager.default.fileExists(atPath: notesURL.path) else {
            return VellemEntry(date: .now, notes: [], status: "Missing notes file")
        }

        guard let data = coordinatedData(at: notesURL) else {
            return VellemEntry(date: .now, notes: [], status: "Can't read notes")
        }

        guard let notes = try? JSONDecoder().decode([WidgetNote].self, from: data) else {
            return VellemEntry(date: .now, notes: [], status: "Can't decode notes")
        }

        let folders = loadFolders(at: foldersURL)
        let visibleNotes = Array(notes
            .filter { !$0.isDailyNote && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(8))
            .map { note in
                var note = note
                note.provenance = provenanceLabel(for: note, folders: folders)
                return note
            }
        return VellemEntry(date: .now, notes: visibleNotes, status: visibleNotes.isEmpty ? "No inbox notes yet." : nil)
    }

    private func coordinatedData(at url: URL) -> Data? {
        var data: Data?
        var coordinationError: NSError?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordURL in
            data = try? Data(contentsOf: coordURL)
        }
        return data
    }

    private func loadFolders(at url: URL) -> [WidgetFolder] {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = coordinatedData(at: url),
              let folders = try? JSONDecoder().decode([WidgetFolder].self, from: data) else {
            return []
        }
        return folders
    }

    private func provenanceLabel(for note: WidgetNote, folders: [WidgetFolder]) -> String? {
        if let folderID = note.folderID,
           let folder = folders.first(where: { $0.id == folderID }) {
            return folder.name
        }
        if note.isFromCodex {
            return "Codex"
        }
        if note.isFromClaude {
            return "Claude"
        }
        let sourceApp = note.sourceApp?.trimmingCharacters(in: .whitespacesAndNewlines)
        return sourceApp?.isEmpty == false ? sourceApp : "Sans dossier"
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
            Text("Inbox")
                .font(.headline)
            Spacer()
            Link(destination: .vellemNewNote) {
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
        Link(destination: .vellemNote(note.id)) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(note.title)
                        .font(.callout)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if let provenance = note.provenance,
                       !provenance.isEmpty {
                        Text(provenance)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.secondary.opacity(0.12), in: Capsule())
                    }
                }
                Text(note.preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(previewLineLimit)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

struct VellemWidget: Widget {
    let kind = "VellemWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VellemProvider()) { entry in
            VellemWidgetView(entry: entry)
        }
        .configurationDisplayName("Vellem")
        .description("Inbox notes and one-tap capture.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

@main
struct VellemWidgetBundle: WidgetBundle {
    var body: some Widget {
        VellemWidget()
    }
}
