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
    @State private var renamingFolderID: UUID?
    @State private var renameDraft: String = ""
    @State private var hoveredFolderID: UUID?
    @State private var isHoveringInbox = false
    @State private var isHoveringToday = false
    @State private var isHoveringFoldersHeader = false
    @AppStorage(AppPreferences.colorSidebarKey) private var colorSidebar = true
    @AppAccent private var accent
    private let sidebarIconSize: CGFloat = 18
    private let sidebarIconFrameWidth: CGFloat = 22
    // Static: NSColor(dynamicProvider:) adapts at draw time — no need to recreate each render.
    private static let smartFolderInk = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedWhite: 0.85, alpha: 1)
            : NSColor(calibratedWhite: 0.22, alpha: 1)
    }))

    var body: some View {
        ZStack {
            accent.color
                .opacity(colorSidebar ? 0.12 : 0)
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    inboxRow

                    todayRow

                    if hasItemsBelowTopSection {
                        sectionGap
                    }

                    systemFoldersSection

                    if !systemFolders.isEmpty && !regularFolders.isEmpty {
                        sectionGap
                    }

                    foldersSection
                }
                .padding(.vertical, 8)
            }
        }
        .tint(accent.color)
        .accentColor(accent.color)
        .navigationTitle("Vellem")
    }

    // MARK: - Sections

    private var inboxRow: some View {
        let count = store.inboxUnreadCount

        return HStack(spacing: 8) {
            Image(systemName: "tray.full")
                .font(.system(size: sidebarIconSize, weight: .semibold))
                .foregroundStyle(Self.smartFolderInk)
                .frame(width: sidebarIconFrameWidth, alignment: .leading)

            Text("Inbox")
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
                .fill(store.isInboxSelected ? accent.color.opacity(0.34) : (isHoveringInbox ? accent.color.opacity(0.18) : Color.clear))
        )
        .padding(.leading, 8)
        .padding(.trailing, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            store.selectInbox()
        }
        .onHover { hovering in
            isHoveringInbox = hovering
        }
    }

    private var todayRow: some View {
        let count = store.todayUnreadCount

        return HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: sidebarIconSize, weight: .semibold))
                .foregroundStyle(Self.smartFolderInk)
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
        VStack(alignment: .leading, spacing: 2) {
            folderSectionHeader

            if !regularFolders.isEmpty {
                ForEach(regularFolders) { folder in
                    folderRow(folder)
                }
            }
        }
    }

    private var systemFoldersSection: some View {
        Group {
            if !systemFolders.isEmpty {
                sectionHeader("Smart folders")

                ForEach(systemFolders) { folder in
                    folderRow(folder)
                }
            }
        }
    }

    private var sectionGap: some View {
        Color.clear
            .frame(height: 12)
    }

    private var folderSectionHeader: some View {
        HStack(spacing: 6) {
            Text("Folders")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button {
                addFolder()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 15, height: 15)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .opacity(isHoveringFoldersHeader ? 1 : 0)
            .allowsHitTesting(isHoveringFoldersHeader)
            .help("New folder")
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHoveringFoldersHeader = hovering
        }
    }

    private func folderRow(_ folder: Folder) -> some View {
        let isHovering = hoveredFolderID == folder.id
        let isSelected = !store.isInboxSelected && !store.isTodaySelected && store.selectedFolderID == folder.id
        let count = store.unreadNoteCountForDisplay(in: folder)

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
        folder.isSmart ? Self.smartFolderInk : (FolderColor.named(folder.color)?.swiftUIColor ?? .primary)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 6)
    }

    private var systemFolders: [Folder] {
        store.folders.filter { $0.isSmart && $0.kind != .smartPromptLibrary }
    }

    private var regularFolders: [Folder] {
        store.folders.filter { !$0.isSmart }
    }

    private var hasItemsBelowTopSection: Bool {
        !systemFolders.isEmpty || !regularFolders.isEmpty
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

}
