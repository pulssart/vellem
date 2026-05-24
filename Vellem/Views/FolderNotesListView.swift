import AppKit
import SwiftUI

struct FolderNotesListView: View {
    @ObservedObject var store: NotesStore
    let folder: Folder
    @Environment(\.openWindow) private var openWindow
    @State private var isDropping = false
    @State private var copiedIntegrationSetup = false

    private var notes: [Note] {
        store.notes.filter { $0.folderID == folder.id && !$0.isDailyNote }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if notes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(notes) { note in
                            FolderNoteListRow(note: note, onOpenViewer: {
                                openInFloatingViewer(note)
                            }) {
                                select(note)
                            }
                            .contextMenu {
                                noteContextMenu(note)
                            }
                            .draggable(note.id.uuidString) {
                                FolderNoteListRow(note: note) {}
                                    .frame(width: 280)
                                    .padding(6)
                                    .background(Color(nsColor: .windowBackgroundColor))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle(folder.name)
        .background(Color(nsColor: .textBackgroundColor))
        .overlay {
            if isDropping {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(nsColor: .systemYellow), lineWidth: 2)
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: String.self) { items, _ in
            handleDrop(items)
        } isTargeted: { hovering in
            isDropping = hovering
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: folder.systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(FolderColor.named(folder.color)?.swiftUIColor ?? Color(nsColor: .systemYellow))

            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)

                Text("\(notes.count) note\(notes.count > 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                createNoteInFolder()
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(.borderless)
            .help("New note in folder")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var emptyState: some View {
        Group {
            if let guide = IntegrationGuide(folder: folder) {
                integrationEmptyState(guide)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: folder.outlineSystemImage)
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(.tertiary)

                    Text("No notes in this folder")
                        .font(.headline)

                    Text("Drop notes here or create one from the top right.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private func integrationEmptyState(_ guide: IntegrationGuide) -> some View {
        VStack(spacing: 16) {
            Image(systemName: folder.outlineSystemImage)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(FolderColor.named(folder.color)?.swiftUIColor ?? Color(nsColor: .systemYellow))

            VStack(spacing: 5) {
                Text("Connect \(folder.name) to Vellem")
                    .font(.headline)

                Text("Add this MCP server config, then ask \(folder.name) to wire it for you.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(guide.config)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )

                Text("Prompt")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(guide.prompt)
                    .font(.caption)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    copy(guide.clipboardText)
                    copiedIntegrationSetup = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copiedIntegrationSetup = false
                    }
                } label: {
                    Label(copiedIntegrationSetup ? "Copied" : "Copy setup", systemImage: copiedIntegrationSetup ? "checkmark" : "doc.on.doc")
                }
                .controlSize(.small)
                .padding(.top, 4)
            }
            .frame(maxWidth: 560)
        }
    }

    @ViewBuilder
    private func noteContextMenu(_ note: Note) -> some View {
        Button("Open in floating window") {
            openInFloatingViewer(note)
        }
        Menu("Move to") {
            Button("No folder") {
                store.moveNote(note.id, toFolder: nil)
            }
            if !store.folders.isEmpty {
                Divider()
                ForEach(store.folders) { targetFolder in
                    Button(targetFolder.name) {
                        store.moveNote(note.id, toFolder: targetFolder.id)
                    }
                }
            }
        }
        Button("Copy") {
            copy(note.text)
        }
        Button("Delete", role: .destructive) {
            store.delete(note)
            store.selectedNoteID = nil
        }
    }

    private func select(_ note: Note) {
        store.selectedFolderID = folder.id
        store.selectedNoteID = note.id
    }

    private func createNoteInFolder() {
        let note = store.createDraft()
        store.moveNote(note.id, toFolder: folder.id)
        select(note)
    }

    private func handleDrop(_ items: [String]) -> Bool {
        var moved = false
        for item in items {
            guard let uuid = UUID(uuidString: item) else { continue }
            store.moveNote(uuid, toFolder: folder.id)
            moved = true
        }
        return moved
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func openInFloatingViewer(_ note: Note) {
        store.viewerNoteID = note.id
        openWindow(id: "note-viewer")
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct IntegrationGuide {
    let config: String
    let prompt: String
    let clipboardText: String

    init?(folder: Folder) {
        switch folder.kind {
        case .smartClaude:
            config = """
            {
              "mcpServers": {
                "vellem": {
                  "command": "/Applications/Vellem.app/Contents/Resources/vellem-mcp"
                }
              }
            }
            """
            prompt = "Add this MCP server to Claude Desktop, restart Claude, then send notes and reports to Vellem with folder_name: \"Claude\"."
        case .smartCodex:
            config = """
            [mcp_servers.vellem]
            command = "/Applications/Vellem.app/Contents/Resources/vellem-mcp"
            """
            prompt = "Add this MCP server to Codex, then use it to send reports, analyses, diagnostics, and notes to Vellem with folder_name: \"Codex\"."
        default:
            return nil
        }
        clipboardText = """
        \(prompt)

        \(config)
        """
    }
}

struct FolderNoteEditorContainer: View {
    @ObservedObject var store: NotesStore
    let folder: Folder
    let note: Note

    var body: some View {
        NoteEditorView(store: store, note: note)
    }
}

struct TodayNotesListView: View {
    @ObservedObject var store: NotesStore
    @Environment(\.openWindow) private var openWindow

    private var notes: [Note] {
        store.notes.filter { !$0.isDailyNote && Calendar.current.isDateInToday($0.createdAt) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if notes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(notes) { note in
                            FolderNoteListRow(note: note, onOpenViewer: {
                                openInFloatingViewer(note)
                            }) {
                                store.selectNote(note.id, inToday: true)
                            }
                            .contextMenu {
                                noteContextMenu(note)
                            }
                            .draggable(note.id.uuidString) {
                                FolderNoteListRow(note: note) {}
                                    .frame(width: 280)
                                    .padding(6)
                                    .background(Color(nsColor: .windowBackgroundColor))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Today")
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color(nsColor: .systemYellow))

            VStack(alignment: .leading, spacing: 2) {
                Text("Today")
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)

                Text("\(notes.count) note\(notes.count > 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.tertiary)

            Text("No notes today")
                .font(.headline)

            Text("Notes created today will appear here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    @ViewBuilder
    private func noteContextMenu(_ note: Note) -> some View {
        Button("Open in floating window") {
            openInFloatingViewer(note)
        }
        Menu("Move to") {
            Button("No folder") {
                store.moveNote(note.id, toFolder: nil)
            }
            if !store.folders.isEmpty {
                Divider()
                ForEach(store.folders) { targetFolder in
                    Button(targetFolder.name) {
                        store.moveNote(note.id, toFolder: targetFolder.id)
                    }
                }
            }
        }
        Button("Copy") {
            copy(note.text)
        }
        Button("Delete", role: .destructive) {
            store.delete(note)
            store.selectedNoteID = nil
        }
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func openInFloatingViewer(_ note: Note) {
        store.viewerNoteID = note.id
        openWindow(id: "note-viewer")
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct TodayNoteEditorContainer: View {
    @ObservedObject var store: NotesStore
    let note: Note

    var body: some View {
        NoteEditorView(store: store, note: note)
    }
}

private struct FolderNoteListRow: View {
    let note: Note
    var onOpenViewer: (() -> Void)? = nil
    let onSelect: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(note.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)

                    Text(note.preview)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(note.updatedAt, style: .relative)
                        Text("\(note.wordCount) words")
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }

                Spacer()

                if let onOpenViewer, isHovering {
                    Button {
                        onOpenViewer()
                    } label: {
                        Image(systemName: "rectangle.on.rectangle")
                    }
                    .buttonStyle(.borderless)
                    .help("Open in floating window")
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isHovering ? .secondary : .tertiary)
                    .padding(.top, 3)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering ? Color(nsColor: .systemYellow).opacity(0.16) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
