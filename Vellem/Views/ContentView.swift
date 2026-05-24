import SwiftUI

struct ContentView: View {
    @ObservedObject var store: NotesStore
    @Environment(\.openSettings) private var openSettings
    @AppStorage(AppPreferences.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false
    @State private var showsOnboarding = false
    @AppAccent private var accent

    var body: some View {
        NavigationSplitView {
            RecentNotesView(store: store)
        } detail: {
            if store.isTodaySelected {
                if let note = selectedNote, isCreatedToday(note) {
                    TodayNoteEditorContainer(store: store, note: note)
                } else {
                    TodayNotesListView(store: store)
                }
            } else if let folder = selectedFolder {
                if let note = selectedNote, note.folderID == folder.id {
                    FolderNoteEditorContainer(store: store, folder: folder, note: note)
                } else {
                    FolderNotesListView(store: store, folder: folder)
                }
            } else if let note = store.selectedNote {
                NoteEditorView(store: store, note: note)
            } else {
                EmptyNotesView(store: store)
            }
        }
        .toolbarBackground(accent.color.opacity(0.28), for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbar {
            if isShowingFolderNote || isShowingTodayNote {
                ToolbarItem(placement: .navigation) {
                    Button {
                        if store.isTodaySelected {
                            store.selectToday()
                        } else {
                            store.selectedNoteID = nil
                        }
                    } label: {
                        Label(backButtonLabel, systemImage: "chevron.left")
                    }
                    .labelStyle(.iconOnly)
                    .help(backButtonLabel)
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.selectToday()
                } label: {
                    Label("Today", systemImage: "calendar")
                }
                .labelStyle(.iconOnly)
                .help("Today")

                Button {
                    store.createDraft()
                } label: {
                    Label("New Note", systemImage: "square.and.pencil")
                }
                .labelStyle(.iconOnly)
                .help("New Note")

                Button {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .labelStyle(.iconOnly)
                .help("Settings")
            }
        }
        .sheet(isPresented: $showsOnboarding) {
            OnboardingView(isPresented: $showsOnboarding)
        }
        .onAppear {
            guard !hasCompletedOnboarding else { return }
            DispatchQueue.main.async {
                showsOnboarding = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .vellemShowOnboarding)) { _ in
            showsOnboarding = true
        }
    }

    private var selectedFolder: Folder? {
        guard let selectedFolderID = store.selectedFolderID else { return nil }
        return store.folders.first { $0.id == selectedFolderID }
    }

    private var selectedNote: Note? {
        guard let selectedNoteID = store.selectedNoteID else { return nil }
        return store.notes.first { $0.id == selectedNoteID }
    }

    private var isShowingFolderNote: Bool {
        guard !store.isTodaySelected else { return false }
        guard let folder = selectedFolder, let note = selectedNote else { return false }
        return note.folderID == folder.id
    }

    private var isShowingTodayNote: Bool {
        guard store.isTodaySelected, let note = selectedNote else { return false }
        return isCreatedToday(note)
    }

    private var backButtonLabel: String {
        store.isTodaySelected ? "Back to today" : "Back to folder"
    }

    private func isCreatedToday(_ note: Note) -> Bool {
        Calendar.current.isDateInToday(note.createdAt)
    }
}
