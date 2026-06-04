import SwiftUI

struct ContentView: View {
    @ObservedObject var store: NotesStore
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @AppStorage(AppPreferences.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false
    @State private var showsOnboarding = false
    @State private var showsUnreadOnly = false
    @State private var showsPreview = true
    @State private var showsProvenance = true
    @State private var sortsNewestFirst = true
    @State private var showsListDisplayOptions = false
    @SceneStorage("VellemDecisionInspectorVisible") private var showsDecisionInspector = false
    @AppStorage(AppPreferences.colorTopBarKey) private var colorTopBar = true
    @AppAccent private var accent

    var body: some View {
        NavigationSplitView {
            RecentNotesView(store: store)
                .background(SplitViewAutosave(name: "VellemSidebarSplit"))
                .navigationSplitViewColumnWidth(
                    min: sidebarColumnMinWidth,
                    ideal: sidebarColumnIdealWidth,
                    max: sidebarColumnMaxWidth
                )
        } detail: {
            mainContent
        }
        .toolbarBackground(colorTopBar ? accent.color.opacity(0.28) : Color.clear, for: .windowToolbar)
        .toolbarBackground(colorTopBar ? .visible : .automatic, for: .windowToolbar)
        .background(MainWindowToolbarTint(isEnabled: colorTopBar, accent: accent))
        .toolbar {
            if showsColumnToolbarControls {
                ToolbarItemGroup {
                    Button {
                        showsUnreadOnly.toggle()
                    } label: {
                        Label("Unread only", systemImage: "line.3.horizontal.decrease")
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(showsUnreadOnly ? accent.color : Color.primary)
                    .help("Unread only")
                    .accessibilityIdentifier("column-list-filter-button")

                    Button {
                        showsListDisplayOptions.toggle()
                    } label: {
                        Label("List display", systemImage: "ellipsis")
                    }
                    .labelStyle(.iconOnly)
                    .help("List display")
                    .accessibilityIdentifier("column-list-display-button")
                    .popover(isPresented: $showsListDisplayOptions, arrowEdge: .top) {
                        ColumnListDisplayOptionsPopover(
                            showsUnreadOnly: $showsUnreadOnly,
                            showsPreview: $showsPreview,
                            showsProvenance: $showsProvenance,
                            sortsNewestFirst: $sortsNewestFirst,
                            canCreateNote: canCreateNoteFromColumnToolbar,
                            createNote: {
                                if let selectedFolder, selectedFolder.kind != .smartPromptLibrary {
                                    createNote(in: selectedFolder)
                                }
                            }
                        )
                    }
                }

                ToolbarSpacer(.flexible)
            }

            ToolbarItemGroup {
                Button {
                    showsDecisionInspector.toggle()
                } label: {
                    Label(decisionToolbarLabel, systemImage: decisionToolbarSystemImage)
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(showsDecisionInspector ? accent.color : Color.primary)
                .disabled(decisionToolbarNote == nil)
                .help("Decision context")
                .keyboardShortcut("d", modifiers: [.command, .option])

                Button {
                    openWindow(id: "quick-capture")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("New Note", systemImage: "square.and.pencil")
                }
                .labelStyle(.iconOnly)
                .help("Quick Capture")

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

    private var selectedInboxNote: Note? {
        guard let note = selectedNote,
              store.inboxNotes.contains(where: { $0.id == note.id }),
              notePassesColumnFilters(note)
        else { return nil }
        return note
    }

    private var usesThreeColumnLayout: Bool {
        if store.isInboxSelected {
            return true
        }

        if store.isTodaySelected {
            return true
        }

        guard let selectedFolder else { return false }
        return selectedFolder.kind != .smartPromptLibrary
    }

    private var showsColumnToolbarControls: Bool {
        store.isInboxSelected || canCreateNoteFromColumnToolbar
    }

    private var canCreateNoteFromColumnToolbar: Bool {
        guard let selectedFolder else { return false }
        return selectedFolder.kind != .smartPromptLibrary
    }

    @ViewBuilder
    private var mainContent: some View {
        if let folder = selectedFolder, folder.kind == .smartPromptLibrary {
            FolderNotesListView(
                store: store,
                folder: folder,
                showsUnreadOnly: $showsUnreadOnly,
                showsPreview: $showsPreview,
                showsProvenance: $showsProvenance,
                sortsNewestFirst: $sortsNewestFirst
            )
        } else if usesThreeColumnLayout {
            HSplitView {
                scopedNotesList
                    .frame(minWidth: 220, idealWidth: 380, maxWidth: 560)
                    .background(SplitViewAutosave(name: "VellemListDetailSplit"))

                scopedDetailView
                    .frame(minWidth: 380, idealWidth: 380)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let note = store.selectedNote {
            NoteEditorView(store: store, note: note, showsDecisionInspector: $showsDecisionInspector)
        } else {
            EmptyNotesView(store: store)
        }
    }

    @ViewBuilder
    private var scopedNotesList: some View {
        if store.isInboxSelected {
            InboxNotesListView(
                store: store,
                showsUnreadOnly: $showsUnreadOnly,
                showsPreview: $showsPreview,
                showsProvenance: $showsProvenance,
                sortsNewestFirst: $sortsNewestFirst
            )
        } else if store.isTodaySelected {
            TodayNotesListView(store: store)
        } else if let folder = selectedFolder {
            FolderNotesListView(
                store: store,
                folder: folder,
                showsUnreadOnly: $showsUnreadOnly,
                showsPreview: $showsPreview,
                showsProvenance: $showsProvenance,
                sortsNewestFirst: $sortsNewestFirst
            )
        } else {
            EmptySelectionContentView()
        }
    }

    @ViewBuilder
    private var scopedDetailView: some View {
        if store.isInboxSelected, let note = selectedInboxNote {
            InboxNoteEditorContainer(store: store, note: note, showsDecisionInspector: $showsDecisionInspector)
        } else if store.isTodaySelected, let note = selectedTodayNote {
            TodayNoteEditorContainer(store: store, note: note, showsDecisionInspector: $showsDecisionInspector)
        } else if let folder = selectedFolder, let note = selectedFolderNote(for: folder) {
            FolderNoteEditorContainer(store: store, folder: folder, note: note, showsDecisionInspector: $showsDecisionInspector)
        } else {
            EmptyDetailSelectionView()
        }
    }

    private var decisionToolbarNote: Note? {
        if store.isInboxSelected {
            return selectedInboxNote
        }

        if store.isTodaySelected {
            return selectedTodayNote
        }

        if let folder = selectedFolder {
            return selectedFolderNote(for: folder)
        }

        return store.selectedNote
    }

    private var decisionToolbarLabel: String {
        guard let context = decisionToolbarNote?.decisionContext else {
            return "Decision"
        }

        return context.status().label
    }

    private var decisionToolbarSystemImage: String {
        decisionToolbarNote?.decisionContext?.status().systemImage ?? "scope"
    }

    private var sidebarColumnMinWidth: CGFloat { 220 }

    private var sidebarColumnIdealWidth: CGFloat { 280 }

    private var sidebarColumnMaxWidth: CGFloat { 380 }

    private func isCreatedToday(_ note: Note) -> Bool {
        Calendar.current.isDateInToday(note.createdAt)
    }

    private func selectedFolderNote(for folder: Folder) -> Note? {
        guard let note = selectedNote,
              store.noteMatchesDisplay(note, in: folder),
              notePassesColumnFilters(note)
        else { return nil }
        return note
    }

    private func notePassesColumnFilters(_ note: Note) -> Bool {
        !showsUnreadOnly || !note.isRead
    }

    private func createNote(in folder: Folder) {
        let note = store.createDraft()
        store.moveNote(note.id, toFolder: folder.id)
        store.selectNote(note.id, inFolder: folder.id)
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

struct ColumnListDisplayOptionsPopover: View {
    @Binding var showsUnreadOnly: Bool
    @Binding var showsPreview: Bool
    @Binding var showsProvenance: Bool
    @Binding var sortsNewestFirst: Bool

    var canCreateNote: Bool
    var createNote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Unread only", isOn: $showsUnreadOnly)
            Toggle("Show previews", isOn: $showsPreview)
            Toggle("Show provenance tags", isOn: $showsProvenance)

            Divider()

            Picker("Sort", selection: $sortsNewestFirst) {
                Text("Newest first").tag(true)
                Text("Oldest first").tag(false)
            }
            .pickerStyle(.radioGroup)

            if canCreateNote {
                Divider()

                Button("New note in folder", action: createNote)
            }
        }
        .padding(14)
        .frame(width: 220)
    }
}
