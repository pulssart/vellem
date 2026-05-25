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
    @State private var isAllNotesCollapsed = false
    @AppAccent private var accent
    private let sidebarIconSize: CGFloat = 18
    private let sidebarIconFrameWidth: CGFloat = 22
    private let smartFolderInk = Color(nsColor: NSColor(calibratedWhite: 0.22, alpha: 1))

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
        .tint(accent.color)
        .accentColor(accent.color)
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
                .font(.system(size: sidebarIconSize, weight: .semibold))
                .foregroundStyle(smartFolderInk)
                .frame(width: sidebarIconFrameWidth, alignment: .leading)

            Text("Today")
                .font(.system(size: 15))
                .lineLimit(1)

            Spacer()

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(store.isTodaySelected ? accent.color.opacity(0.34) : (isHoveringToday ? accent.color.opacity(0.18) : Color.clear))
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
            collapsibleSectionHeader(
                store.folders.isEmpty ? "Notes" : "All notes",
                isCollapsed: isAllNotesCollapsed
            ) {
                isAllNotesCollapsed.toggle()
            }

            if !isAllNotesCollapsed {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(allNotes) { note in
                        row(for: note)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            isRootDropTargeted ? accent.color : Color.clear,
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
    }

    private func folderRow(_ folder: Folder) -> some View {
        let isHovering = hoveredFolderID == folder.id
        let isSelected = !store.isTodaySelected && store.selectedFolderID == folder.id
        let count = store.noteCountForDisplay(in: folder)

        return HStack(spacing: 8) {
            Image(systemName: folderIconName(for: folder, selected: isSelected))
                .font(.system(size: sidebarIconSize, weight: .semibold))
                .foregroundStyle(folderIconColor(for: folder))
                .frame(width: sidebarIconFrameWidth, alignment: .leading)

            if renamingFolderID == folder.id {
                TextField("Folder name", text: $renameDraft, onCommit: {
                    store.renameFolder(folder.id, to: renameDraft)
                    renamingFolderID = nil
                })
                .textFieldStyle(.roundedBorder)
                .onExitCommand { renamingFolderID = nil }
            } else {
                Text(folder.name)
                    .font(.system(size: 15))
                    .lineLimit(1)
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? accent.color.opacity(0.34) : (isHovering ? accent.color.opacity(0.18) : Color.clear))
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

    private func folderIconColor(for folder: Folder) -> Color {
        folder.isSmart ? smartFolderInk : (FolderColor.named(folder.color)?.swiftUIColor ?? .primary)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 6)
    }

    private func collapsibleSectionHeader(_ title: String, isCollapsed: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    private var todayNotes: [Note] {
        filteredNotes.filter { Calendar.current.isDateInToday($0.createdAt) }
    }

    private var filteredRegularNotes: [Note] {
        filteredNotes.filter { !$0.isDailyNote }
    }

    private var systemFolders: [Folder] {
        store.folders.filter { $0.isSmart }
    }

    private var regularFolders: [Folder] {
        store.folders.filter { !$0.isSmart }
    }

    private var allNotes: [Note] {
        filteredNotes
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
    @AppAccent private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if note.isDailyNote {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    if !note.isRead {
                        Circle()
                            .fill(accent.color)
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
                            .font(.system(size: 12, weight: .medium))
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
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? accent.color.opacity(0.45) : Color.clear)
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
