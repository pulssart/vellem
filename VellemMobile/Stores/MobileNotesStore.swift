import Combine
import Foundation

@MainActor
final class MobileNotesStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published private(set) var folders: [Folder] = []
    @Published private(set) var isLoading = false
    @Published private(set) var syncError: String?
    @Published var selectedFolderID: Folder.ID?

    private var refreshTimer: Timer?

    var rootNotes: [Note] {
        notes.filter { $0.folderID == nil && !$0.isDailyNote }
    }

    var inboxNotes: [Note] {
        notes.filter { !$0.isDailyNote }
    }

    var inboxUnreadCount: Int {
        inboxNotes.reduce(0) { $0 + ($1.isRead ? 0 : 1) }
    }

    var todayNotes: [Note] {
        notes.filter { Calendar.current.isDateInToday($0.createdAt) }
    }

    var todayUnreadCount: Int {
        notes.reduce(0) { total, note in
            total + (Calendar.current.isDateInToday(note.createdAt) && !note.isRead ? 1 : 0)
        }
    }

    var rootUnreadCount: Int {
        notes.reduce(0) { total, note in
            total + (note.folderID == nil && !note.isDailyNote && !note.isRead ? 1 : 0)
        }
    }

    var selectedFolder: Folder? {
        guard let selectedFolderID else { return nil }
        return folders.first { $0.id == selectedFolderID }
    }

    var visibleNotes: [Note] {
        guard let selectedFolder else { return rootNotes }
        return notesForDisplay(in: selectedFolder)
    }

    func start() {
        Task {
            await refresh(shouldNotify: false)
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh(shouldNotify: true)
            }
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refresh(shouldNotify: Bool = true) async {
        isLoading = true
        syncError = nil

        do {
            async let notesTask = Task.detached(priority: .utility) {
                try CloudMirrorStore.loadNotes([Note].self)
            }.value
            async let foldersTask = Task.detached(priority: .utility) {
                try CloudMirrorStore.loadFolders([Folder].self)
            }.value

            notes = try await notesTask.sorted { $0.updatedAt > $1.updatedAt }
            folders = try await foldersTask.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            normalizeSelection()
            MobileFolderNotificationScanner.scan(notes: notes, folders: folders, shouldNotify: shouldNotify)
        } catch CloudMirrorError.unavailable {
            syncError = "iCloud n'est pas disponible sur cet appareil."
        } catch {
            syncError = "Synchronisation impossible pour le moment."
        }

        isLoading = false
    }

    func select(_ folderID: Folder.ID?) {
        selectedFolderID = folderID
    }

    func notesForDisplay(in folder: Folder) -> [Note] {
        notes.filter { noteMatchesDisplay($0, in: folder) }
    }

    func noteCountForDisplay(in folder: Folder) -> Int {
        notes.reduce(0) { $0 + (noteMatchesDisplay($1, in: folder) ? 1 : 0) }
    }

    func unreadNoteCountForDisplay(in folder: Folder) -> Int {
        notes.reduce(0) { $0 + (noteMatchesDisplay($1, in: folder) && !$1.isRead ? 1 : 0) }
    }

    func provenanceLabel(for note: Note) -> String {
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

        if let sourceApp = note.sourceApp,
           !sourceApp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return sourceApp
        }

        return "Sans dossier"
    }

    func noteMatchesDisplay(_ note: Note, in folder: Folder) -> Bool {
        guard !note.isDailyNote else { return false }

        switch folder.kind {
        case .smartClaude:
            return note.folderID == folder.id || note.isFromClaude
        case .smartCodex:
            return note.folderID == folder.id || note.isFromCodex
        case .smartPromptLibrary:
            return false
        case .smartServices, .regular:
            return note.folderID == folder.id
        }
    }

    private func normalizeSelection() {
        if let selectedFolderID,
           folders.contains(where: { $0.id == selectedFolderID }) {
            return
        }

        selectedFolderID = folders.first?.id
    }
}
