import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MailboxFolderPanel: View {
    @ObservedObject var store: NotesStore
    let isFullScreen: Bool
    let close: () -> Void
    let onNavigate: () -> Void
    @State private var naming: FolderNameRequest?
    @State private var confirmDeletion: Folder?
    @State private var hovered: UUID?
    @State private var dropTarget: UUID?

    private var root: SidebarMailbox { store.sidebarRoot }
    private var folders: [Folder] {
        root.visibleFolders(in: store.folders, notes: store.notes)
    }
    private var rootLabel: LocalizedStringKey {
        switch root {
        case .today: "Today’s notes"
        case .folders: "All filed notes"
        default: "All notes"
        }
    }

    var body: some View {
        let rootHasUnread = store.hasUnread(in: root)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(LocalizedStringKey(root.title)).font(.system(size: 17, weight: .semibold)).lineLimit(1)
                Spacer(minLength: 4)
                Button(action: close) { Image(systemName: "sidebar.left") }
                    .help("Collapse folders").accessibilityLabel("Collapse folders")
            }
            .padding(.horizontal, 14).frame(height: 45)
            .background { Color.clear.contentShape(Rectangle()).gesture(WindowDragGesture()) }

            Button {
                onNavigate()
                store.selectRoot(root)
            } label: {
                HStack {
                    Label(rootLabel, systemImage: "tray.2")
                    Spacer(minLength: 2)
                    if rootHasUnread { MailboxUnreadDot() }
                }
                .font(.system(size: 13, weight: .medium)).padding(.horizontal, 10)
                .frame(height: 32).contentShape(Rectangle())
            }
            .background(.white.opacity(store.selectedFolderID == nil ? 0.12 : 0), in: RoundedRectangle(cornerRadius: 7))
            .accessibilityAddTraits(store.selectedFolderID == nil ? .isSelected : [])
            .accessibilityValue(rootHasUnread ? Text("Unread") : Text(""))
            .padding(.horizontal, 8)

            HStack {
                Text("Folders").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Button { naming = FolderNameRequest(folder: nil) } label: {
                    Image(systemName: "plus").frame(width: 24, height: 24).contentShape(Rectangle())
                }.help("New folder").accessibilityLabel("New folder")
            }.padding(.leading, 16).padding(.trailing, 9).padding(.top, 22)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if folders.isEmpty {
                        Button("Create a folder…") { naming = FolderNameRequest(folder: nil) }
                            .font(.callout).foregroundStyle(.secondary)
                            .padding(.leading, 17).padding(.top, 5)
                    } else {
                        let groups = Dictionary(grouping: folders, by: { root == .folders ? ($0.mailbox ?? "") : "" })
                        ForEach(groups.keys.sorted(), id: \.self) { key in
                            if !key.isEmpty {
                                Text(LocalizedStringKey(key)).font(.caption).foregroundStyle(.secondary)
                                    .padding(.horizontal, 17).padding(.top, 9)
                            }
                            ForEach(groups[key] ?? []) { folder in row(folder) }
                        }
                    }
                }
            }
        }
        .padding(.top, isFullScreen ? 14 : 32).padding(.bottom, 8)
        .buttonStyle(.plain)
        .environment(\.colorScheme, .dark)
        .sheet(item: $naming) { request in
            FolderNameSheet(folder: request.folder, root: root, store: store) { name in
                if let folder = request.folder {
                    store.renameFolder(folder.id, to: name)
                } else {
                    store.createFolder(name: name, mailbox: root.folderKey)
                }
                naming = nil
            }
        }
        .alert("Delete folder?", isPresented: Binding(get: { confirmDeletion != nil }, set: { if !$0 { confirmDeletion = nil } }),
               presenting: confirmDeletion) { folder in
            Button("Cancel", role: .cancel) {}
            Button("Delete folder", role: .destructive) { store.deleteFolder(folder.id) }
        } message: { folder in Text("“\(folder.name)” will be removed. Its notes stay in your library.") }
    }

    private func row(_ folder: Folder) -> some View {
        let selected = store.selectedFolderID == folder.id
        let hasUnread = store.unreadNoteCountForDisplay(in: folder) > 0
        return Button {
            onNavigate()
            store.selectFolder(folder.id, from: root)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selected ? "folder.fill" : "folder")
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
                Text(folder.name).lineLimit(1)
                Spacer(minLength: 2)
                if hasUnread { MailboxUnreadDot() }
            }.font(.system(size: 13))
            .padding(.horizontal, 10).frame(height: 31).contentShape(Rectangle())
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(hasUnread ? Text("Unread") : Text(""))
        .background(.white.opacity(selected || dropTarget == folder.id ? 0.16 : hovered == folder.id ? 0.07 : 0),
                    in: RoundedRectangle(cornerRadius: 7))
        .onHover { hovered = $0 ? folder.id : nil }
        .onDrop(of: [UTType.text], isTargeted: Binding(
            get: { dropTarget == folder.id },
            set: { if $0 { dropTarget = folder.id } else if dropTarget == folder.id { dropTarget = nil } }
        )) { providers in
            let strings = providers.filter { $0.canLoadObject(ofClass: NSString.self) }
            for provider in strings {
                provider.loadObject(ofClass: NSString.self) { value, _ in
                    guard let value = value as? String, let id = UUID(uuidString: value) else { return }
                    Task { @MainActor in store.moveNote(id, toFolder: folder.id) }
                }
            }
            return !strings.isEmpty
        }
        .contextMenu {
            Button("Rename…") { naming = FolderNameRequest(folder: folder) }
            Divider()
            Button("Delete folder…", role: .destructive) { confirmDeletion = folder }
        }
        .padding(.horizontal, 8)
    }
}

private struct FolderNameRequest: Identifiable {
    let id = UUID()
    let folder: Folder?
}

private struct FolderNameSheet: View {
    let folder: Folder?
    let root: SidebarMailbox
    @ObservedObject var store: NotesStore
    let save: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @State private var name = ""

    private var cleaned: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var duplicate: Bool {
        let key = folder == nil ? root.folderKey : folder?.mailbox
        let matches = store.folders.filter { $0.id != folder?.id && $0.name.localizedCaseInsensitiveCompare(cleaned) == .orderedSame }
        if matches.contains(where: { $0.mailbox == key }) { return true }
        guard case .agent = root, !matches.isEmpty else { return false }
        return !root.visibleFolders(in: matches, notes: store.notes).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(folder == nil ? "New folder" : "Rename folder").font(.title3.bold())
            TextField("Folder name", text: $name).textFieldStyle(.roundedBorder).focused($focused)
            if duplicate { Text("A folder with this name already exists here.").font(.callout).foregroundStyle(.secondary) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(folder == nil ? "Create" : "Save") { save(cleaned) }
                    .keyboardShortcut(.defaultAction).disabled(cleaned.isEmpty || duplicate)
            }
        }.padding(20).frame(width: 300)
        .onAppear { name = folder?.name ?? ""; focused = true }
    }
}
