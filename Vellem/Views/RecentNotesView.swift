import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension FolderColor {
    var swiftUIColor: Color {
        Color(nsColor: nsColor)
    }

    var nsColor: NSColor {
        switch self {
        case .yellow: return .systemYellow
        case .orange: return .systemOrange
        case .red:    return .systemRed
        case .pink:   return .systemPink
        case .purple: return .systemPurple
        case .blue:   return .systemBlue
        case .teal:   return .systemTeal
        case .green:  return .systemGreen
        case .gray:   return .systemGray
        }
    }

    func dotImage(diameter: CGFloat = 12) -> NSImage {
        let size = NSSize(width: diameter, height: diameter)
        let image = NSImage(size: size)
        image.lockFocus()
        nsColor.setFill()
        NSBezierPath(ovalIn: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

struct RecentNotesView: View {
    @ObservedObject var store: NotesStore
    @Environment(\.openWindow) private var openWindow
    @State private var query = ""
    @State private var renamingFolderID: UUID?
    @State private var renameDraft: String = ""
    @State private var hoveredFolderID: UUID?
    @State private var isHoveringToday = false
    @State private var isRootDropTargeted = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                todayRow

                systemFoldersSection

                foldersSection

                rootNotesSection
            }
            .padding(.vertical, 8)
        }
        .tint(Color(nsColor: .systemYellow))
        .accentColor(Color(nsColor: .systemYellow))
        .navigationTitle("Vellem")
        .searchable(text: $query, placement: .sidebar, prompt: "Search notes")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    addFolder()
                } label: {
                    Label("New folder", systemImage: "folder.badge.plus")
                }
                .help("New folder")
            }
        }
    }

    // MARK: - Sections

    private var todayRow: some View {
        let count = todayNotes.count

        return HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color(nsColor: .systemYellow))
                .frame(width: 28, alignment: .leading)

            Text("Today")
                .lineLimit(1)

            Spacer()

            if count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(store.isTodaySelected ? Color(nsColor: .systemYellow).opacity(0.34) : (isHoveringToday ? Color(nsColor: .systemYellow).opacity(0.18) : Color.clear))
        )
        .padding(.leading, 8)
        .padding(.trailing, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            store.selectToday()
        }
        .onHover { hovering in
            isHoveringToday = hovering
        }
    }

    private var foldersSection: some View {
        Group {
            if !regularFolders.isEmpty {
                sectionHeader("Folders")

                ForEach(regularFolders) { folder in
                    folderRow(folder)
                }

                Spacer().frame(height: 8)
            }
        }
    }

    private var systemFoldersSection: some View {
        Group {
            if !systemFolders.isEmpty {
                ForEach(systemFolders) { folder in
                    folderRow(folder)
                }

                Spacer().frame(height: 8)
            }
        }
    }

    private var rootNotesSection: some View {
        Group {
            sectionHeader(store.folders.isEmpty ? "Notes" : "All notes")

            VStack(alignment: .leading, spacing: 2) {
                ForEach(rootNotes) { note in
                    row(for: note)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isRootDropTargeted ? Color(nsColor: .systemYellow) : Color.clear,
                        lineWidth: 1.5
                    )
                    .padding(.horizontal, 4)
            )
            .dropDestination(for: String.self) { items, _ in
                handleDrop(items: items, intoFolder: nil)
            } isTargeted: { hovering in
                isRootDropTargeted = hovering
            }
        }
    }

    private func folderRow(_ folder: Folder) -> some View {
        let isHovering = hoveredFolderID == folder.id
        let isSelected = !store.isTodaySelected && store.selectedFolderID == folder.id
        let count = store.notes.filter { $0.folderID == folder.id }.count

        return HStack(spacing: 8) {
            Image(systemName: folderIconName(for: folder, selected: isSelected))
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(FolderColor.named(folder.color)?.swiftUIColor ?? Color(nsColor: .systemYellow))
                .frame(width: 28, alignment: .leading)

            if renamingFolderID == folder.id {
                TextField("Folder name", text: $renameDraft, onCommit: {
                    store.renameFolder(folder.id, to: renameDraft)
                    renamingFolderID = nil
                })
                .textFieldStyle(.roundedBorder)
                .onExitCommand { renamingFolderID = nil }
            } else {
                Text(folder.name)
                    .lineLimit(1)
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color(nsColor: .systemYellow).opacity(0.34) : (isHovering ? Color(nsColor: .systemYellow).opacity(0.18) : Color.clear))
        )
        .padding(.leading, 8)
        .padding(.trailing, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            selectFolder(folder.id)
        }
        .onHover { hovering in
            hoveredFolderID = hovering ? folder.id : (hoveredFolderID == folder.id ? nil : hoveredFolderID)
        }
        .dropDestination(for: String.self) { items, _ in
            handleDrop(items: items, intoFolder: folder.id)
        } isTargeted: { hovering in
            hoveredFolderID = hovering ? folder.id : (hoveredFolderID == folder.id ? nil : hoveredFolderID)
        }
        .contextMenu {
            if !folder.isSmart {
                Button("Rename") {
                    renameDraft = folder.name
                    renamingFolderID = folder.id
                }
            }
            Menu("Color") {
                Button {
                    store.setFolderColor(folder.id, color: nil)
                } label: {
                    Label("Default", systemImage: folder.color == nil ? "checkmark" : "circle")
                }
                Divider()
                ForEach(FolderColor.allCases) { color in
                    Button {
                        store.setFolderColor(folder.id, color: color)
                    } label: {
                        Label {
                            Text(folder.color == color.rawValue ? "✓ \(color.label)" : color.label)
                        } icon: {
                            Image(nsImage: color.dotImage())
                        }
                    }
                }
            }
            if !folder.isSmart {
                Button("Delete folder", role: .destructive) {
                    store.deleteFolder(folder.id)
                }
            }
        }
    }

    private func folderIconName(for folder: Folder, selected: Bool) -> String {
        selected ? folder.systemImage : folder.outlineSystemImage
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 6)
    }

    @ViewBuilder
    private func row(for note: Note) -> some View {
        NoteRow(
            note: note,
            isSelected: !store.isTodaySelected && store.selectedNoteID == note.id
        ) {
            openInFloatingViewer(note)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            store.selectNote(note.id)
        }
        .draggable(note.id.uuidString) {
            NoteRow(note: note, isSelected: false)
                .frame(width: 240)
                .padding(6)
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(8)
        }
        .contextMenu {
            Button("Open in floating window") {
                openInFloatingViewer(note)
            }
            Menu("Move to") {
                Button("No folder") {
                    store.moveNote(note.id, toFolder: nil)
                }
                if !store.folders.isEmpty {
                    Divider()
                    ForEach(store.folders) { folder in
                        Button(folder.name) {
                            store.moveNote(note.id, toFolder: folder.id)
                        }
                    }
                }
                Divider()
                Button("New folder…") {
                    let folder = store.createFolder(name: "New folder")
                    store.moveNote(note.id, toFolder: folder.id)
                    selectFolder(folder.id)
                    renameDraft = folder.name
                    renamingFolderID = folder.id
                }
            }
            Button("Copy") {
                copy(note.text)
            }
            Button(note.isRead ? "Mark as unread" : "Mark as read") {
                note.isRead ? store.markUnread(note.id) : store.markRead(note.id)
            }
            Button("Delete", role: .destructive) {
                store.delete(note)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 8)
    }

    // MARK: - Filtering

    private var filteredNotes: [Note] {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuery.isEmpty else { return store.notes }

        return store.notes.filter { note in
            note.title.localizedCaseInsensitiveContains(cleanedQuery) ||
            note.text.localizedCaseInsensitiveContains(cleanedQuery)
        }
    }

    private var filteredRegularNotes: [Note] {
        filteredNotes.filter { !$0.isDailyNote }
    }

    private var todayNotes: [Note] {
        filteredRegularNotes.filter { Calendar.current.isDateInToday($0.createdAt) }
    }

    private var systemFolders: [Folder] {
        store.folders.filter { $0.isSmart }
    }

    private var regularFolders: [Folder] {
        store.folders.filter { !$0.isSmart }
    }

    private var rootNotes: [Note] {
        filteredRegularNotes.filter { note in
            guard let fid = note.folderID else { return true }
            return !store.folders.contains(where: { $0.id == fid })
        }
    }

    // MARK: - Actions

    private func selectFolder(_ folderID: UUID) {
        store.selectFolder(folderID)
    }

    private func addFolder() {
        let folder = store.createFolder(name: "New folder")
        selectFolder(folder.id)
        renameDraft = folder.name
        renamingFolderID = folder.id
    }

    private func handleDrop(items: [String], intoFolder folderID: UUID?) -> Bool {
        var moved = false
        for item in items {
            guard let uuid = UUID(uuidString: item) else { continue }
            store.moveNote(uuid, toFolder: folderID)
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

private struct NoteRow: View {
    let note: Note
    let isSelected: Bool
    var onOpenViewer: (() -> Void)? = nil
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if note.isDailyNote {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    if !note.isRead {
                        Circle()
                            .fill(Color(nsColor: .systemYellow))
                            .frame(width: 7, height: 7)
                            .accessibilityLabel("Unread")
                    }

                    Text(note.title)
                        .lineLimit(1)
                        .fontWeight((isSelected || !note.isRead) ? .semibold : .regular)
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
            }

            Text(note.preview)
                .font(.caption)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(note.updatedAt, style: .relative)
                Text("\(note.wordCount) words")
            }
            .font(.caption2)
            .foregroundStyle(isSelected ? .secondary : .tertiary)
            .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color(nsColor: .systemYellow).opacity(0.45) : Color.clear)
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
