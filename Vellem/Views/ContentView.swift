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
                .navigationSplitViewColumnWidth(
                    min: sidebarColumnMinWidth,
                    ideal: sidebarColumnIdealWidth,
                    max: sidebarColumnMaxWidth
                )
        } detail: {
            mainContent
        }
        .toolbarBackground(accent.color.opacity(0.28), for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
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
            showsOnboarding = true
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

    private var selectedTodayNote: Note? {
        guard let note = selectedNote, isCreatedToday(note) else { return nil }
        return note
    }

    private var usesThreeColumnLayout: Bool {
        if store.isTodaySelected {
            return true
        }

        guard let selectedFolder else { return false }
        return selectedFolder.kind != .smartPromptLibrary
    }

    @ViewBuilder
    private var mainContent: some View {
        if let folder = selectedFolder, folder.kind == .smartPromptLibrary {
            FolderNotesListView(store: store, folder: folder)
        } else if usesThreeColumnLayout {
            HSplitView {
                scopedNotesList
                    .frame(minWidth: 220, idealWidth: 320, maxWidth: 560)

                scopedDetailView
                    .frame(minWidth: 380)
            }
            .background(SplitViewAutosave(name: "VellemNoteListSplit"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let note = store.selectedNote {
            NoteEditorView(store: store, note: note)
        } else {
            EmptyNotesView(store: store)
        }
    }

    @ViewBuilder
    private var scopedNotesList: some View {
        if store.isTodaySelected {
            TodayNotesListView(store: store)
        } else if let folder = selectedFolder {
            FolderNotesListView(store: store, folder: folder)
        } else {
            EmptySelectionContentView()
        }
    }

    @ViewBuilder
    private var scopedDetailView: some View {
        if store.isTodaySelected, let note = selectedTodayNote {
            TodayNoteEditorContainer(store: store, note: note)
        } else if let folder = selectedFolder, let note = selectedFolderNote(for: folder) {
            FolderNoteEditorContainer(store: store, folder: folder, note: note)
        } else {
            EmptyDetailSelectionView()
        }
    }

    private var sidebarColumnMinWidth: CGFloat { 220 }

    private var sidebarColumnIdealWidth: CGFloat { 280 }

    private var sidebarColumnMaxWidth: CGFloat { 380 }

    private func isCreatedToday(_ note: Note) -> Bool {
        Calendar.current.isDateInToday(note.createdAt)
    }

    private func selectedFolderNote(for folder: Folder) -> Note? {
        guard let note = selectedNote, store.noteMatchesDisplay(note, in: folder) else { return nil }
        return note
    }
}

private struct EmptySelectionContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.split.2x1")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(.tertiary)

            Text("Choose a folder")
                .font(.headline)

            Text("Its notes will appear here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct EmptyDetailSelectionView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.tertiary)

            Text("Select a note")
                .font(.headline)

            Text("Its content will open on the right.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}
