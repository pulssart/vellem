import SwiftUI

struct MobileRootView: View {
    @ObservedObject var store: MobileNotesStore

    var body: some View {
        NavigationStack {
            MobileSidebarView(store: store)
                .navigationDestination(for: MobileFolderRoute.self) { route in
                    MobileNotesListView(store: store, route: route)
                }
                .navigationDestination(for: Note.self) { note in
                    MobileNoteDetailView(note: note)
                }
        }
        .tint(.primary)
    }
}

enum MobileFolderRoute: Hashable {
    case inbox
    case folder(Folder.ID)
    case today
    case root
}

struct MobileSidebarView: View {
    @ObservedObject var store: MobileNotesStore

    private var systemFolders: [Folder] {
        store.folders.filter { $0.isSmart && $0.kind != .smartPromptLibrary }
    }

    private var regularFolders: [Folder] {
        store.folders.filter { !$0.isSmart }
    }

    var body: some View {
        List {
            Section {
                NavigationLink(value: MobileFolderRoute.inbox) {
                    Label {
                        HStack {
                            Text("Inbox")
                            Spacer()
                            Text("\(store.inboxUnreadCount)")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                    } icon: {
                        Image(systemName: "tray.full")
                            .foregroundStyle(.secondary)
                    }
                }

                NavigationLink(value: MobileFolderRoute.today) {
                    Label {
                        HStack {
                            Text("Today")
                            Spacer()
                            Text("\(store.todayUnreadCount)")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                    } icon: {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !systemFolders.isEmpty {
                Section {
                    ForEach(systemFolders) { folder in
                        folderRow(folder)
                    }
                }
            }

            if !regularFolders.isEmpty {
                Section("Dossiers") {
                    ForEach(regularFolders) { folder in
                        folderRow(folder)
                    }
                }
            }

            Section {
                NavigationLink(value: MobileFolderRoute.root) {
                    Label {
                        HStack {
                            Text("Sans dossier")
                            Spacer()
                            Text("\(store.rootUnreadCount)")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                    } icon: {
                        Image(systemName: "tray")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Vellem")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await store.refresh()
        }
        .overlay {
            if store.isLoading && store.folders.isEmpty {
                ProgressView()
            }
        }
    }

    private func folderRow(_ folder: Folder) -> some View {
        NavigationLink(value: MobileFolderRoute.folder(folder.id)) {
            Label {
                HStack {
                    Text(folder.name)
                    Spacer()
                    Text("\(store.unreadNoteCountForDisplay(in: folder))")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            } icon: {
                Image(systemName: folder.outlineSystemImage)
                    .foregroundStyle(folder.color.uiColor)
            }
        }
    }
}

struct MobileNotesListView: View {
    @ObservedObject var store: MobileNotesStore
    let route: MobileFolderRoute

    private var folder: Folder? {
        guard case let .folder(folderID) = route else { return nil }
        return store.folders.first { $0.id == folderID }
    }

    private var notes: [Note] {
        if route == .inbox {
            return store.inboxNotes
        }

        if route == .today {
            return store.todayNotes
        }

        if let folder {
            return store.notesForDisplay(in: folder)
        }

        return store.rootNotes
    }

    private var title: String {
        if route == .inbox {
            return "Inbox"
        }

        if route == .today {
            return "Today"
        }

        return folder?.name ?? "Sans dossier"
    }

    var body: some View {
        List(notes) { note in
            NavigationLink(value: note) {
                MobileNoteRow(note: note, provenance: route == .inbox ? store.provenanceLabel(for: note) : nil)
            }
        }
        .listStyle(.plain)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await store.refresh()
        }
        .overlay {
            if let syncError = store.syncError {
                ContentUnavailableView("iCloud indisponible", systemImage: "icloud.slash", description: Text(syncError))
            } else if notes.isEmpty && !store.isLoading {
                ContentUnavailableView("Aucune note", systemImage: "doc.text", description: Text("Les notes synchronisées arriveront ici."))
            }
        }
    }
}

struct MobileNoteRow: View {
    let note: Note
    var provenance: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.title)
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(note.preview)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(note.updatedAt, format: .dateTime.day().month().hour().minute())
                .font(.caption)
                .foregroundStyle(.tertiary)

            if let provenance {
                Text(provenance)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.secondary.opacity(0.12))
                    )
            }
        }
        .padding(.vertical, 4)
    }
}

struct MobileNoteDetailView: View {
    let note: Note

    var body: some View {
        MobileMarkdownRenderedView(text: note.text)
        .navigationTitle(note.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension Optional where Wrapped == String {
    var uiColor: Color {
        switch self?.lowercased() {
        case "yellow": .yellow
        case "orange": .orange
        case "red": .red
        case "pink": .pink
        case "purple": .purple
        case "blue": .blue
        case "teal": .teal
        case "green": .green
        case "gray": .gray
        default: .secondary
        }
    }
}
