import AppKit
import Combine
import Foundation

@MainActor
final class NotesStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published private(set) var folders: [Folder] = []
    @Published var selectedNoteID: Note.ID?
    @Published var viewerNoteID: Note.ID?
    @Published var selectedFolderID: Folder.ID?
    @Published private(set) var inboxAgent: InboxAgent?
    @Published private(set) var sidebarRoot: SidebarMailbox = .inbox
    @Published var isInboxSelected = true
    @Published var isTodaySelected = false
    @Published var persistenceError: String?
    @Published private(set) var libraryUnavailable = false

    var viewerNote: Note? {
        guard let viewerNoteID else { return nil }
        return notesByID[viewerNoteID]
    }

    // O(1) lookup index — kept in sync via $notes publisher
    private var notesByID: [Note.ID: Note] = [:]
    private var persistedNotes: [Note] = []
    private var persistedFolders: [Folder] = []
    private var persistenceGeneration = 0
    private var indexCancellable: AnyCancellable?

    private let fileURL: URL
    private let foldersURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var fileWatcher: DispatchSourceFileSystemObject?
    private var foldersWatcher: DispatchSourceFileSystemObject?
    private var externalEventWatcher: DispatchSourceFileSystemObject?
    private var reloadDebounce: DispatchWorkItem?
    private var foldersReloadDebounce: DispatchWorkItem?
    private var externalEventDebounce: DispatchWorkItem?
    private var notifiedExternalNoteIDs = Set<Note.ID>()

    init(fileURL: URL = AppGroup.notesURL, foldersURL: URL = AppGroup.foldersURL) {
        self.fileURL = fileURL
        self.foldersURL = foldersURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // Keep notesByID in sync whenever notes array changes (fires in willSet with new value).
        indexCancellable = $notes.sink { [weak self] newNotes in
            self?.notesByID = Dictionary(newNotes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        }
        load()
        loadFolders()
        ensureSmartFolders()
        startWatchingFile()
        startWatchingFoldersFile()
        startWatchingExternalEvents()
        WidgetReloader.reload()
    }

    deinit {
        fileWatcher?.cancel()
        foldersWatcher?.cancel()
        externalEventWatcher?.cancel()
    }

    // MARK: - Folder API

    var servicesFolderID: Folder.ID? {
        folders.first { $0.kind == .smartServices }?.id
    }

    var hasArchivedCaptures: Bool {
        if folders.contains(where: { $0.mailbox == SidebarMailbox.captures.folderKey }) { return true }
        guard let id = servicesFolderID else { return false }
        return notes.contains { $0.folderID == id }
    }

    var selectedNote: Note? {
        guard let selectedNoteID else { return notes.first }
        return notesByID[selectedNoteID] ?? notes.first
    }

    private func ensureSmartFolders() {
        let normalized = Self.normalizedSystemFolders(folders)
        guard normalized != folders else { return }
        folders = normalized
        saveFolders()
    }

    private static func normalizedSystemFolders(_ input: [Folder]) -> [Folder] {
        // Keep notes already filed in the retired library reachable as a normal folder.
        var result = input.map { folder in
            var folder = folder
            if folder.kind == .smartPromptLibrary { folder.kind = .regular }
            return folder
        }
        let system: [(String, FolderKind)] = [
            ("Claude", .smartClaude),
            ("Codex", .smartCodex),
            ("Quick captures", .smartServices)
        ]
        for (name, kind) in system {
            if let index = result.firstIndex(where: { $0.kind == kind })
                ?? result.firstIndex(where: { $0.mailbox == nil && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
                result[index].kind = kind
                result[index].name = name
            } else {
                result.append(Folder(name: name, kind: kind))
            }
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    @discardableResult
    func createFolder(name: String, mailbox: String? = nil) -> Folder {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = cleaned.isEmpty ? "New folder" : cleaned
        let folder = Folder(name: finalName, mailbox: mailbox)
        folders.append(folder)
        sortFolders()
        if !saveFolders() { folders.removeAll { $0.id == folder.id } }
        return folder
    }

    func renameFolder(_ folderID: Folder.ID, to name: String) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        folders[index].name = cleaned
        sortFolders()
        saveFolders()
    }

    func deleteFolder(_ folderID: Folder.ID) {
        guard let target = folders.first(where: { $0.id == folderID }), !target.isSmart else { return }
        do {
            let (updatedFolders, updatedNotes, hadConflict) = try LibraryWriteLock.withLock(in: fileURL.deletingLastPathComponent()) {
                let folderData = FileManager.default.fileExists(atPath: foldersURL.path) ? try Data(contentsOf: foldersURL) : nil
                let noteData = FileManager.default.fileExists(atPath: fileURL.path) ? try Data(contentsOf: fileURL) : nil
                let diskFolders = try folderData.map { try VellemLibraryValidation.uniqueIDs(decoder.decode([Folder].self, from: $0), kind: "folders") } ?? []
                let diskNotes = try noteData.map { try VellemLibraryValidation.uniqueIDs(decoder.decode([Note].self, from: $0), kind: "notes") } ?? []

                let baseline = Dictionary(uniqueKeysWithValues: persistedFolders.map { ($0.id, $0) })
                let current = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
                var combined = Dictionary(uniqueKeysWithValues: diskFolders.map { ($0.id, $0) })
                for id in baseline.keys where current[id] == nil { combined.removeValue(forKey: id) }
                for folder in folders where baseline[folder.id] != folder { combined[folder.id] = folder }
                combined.removeValue(forKey: folderID)
                let newFolders = combined.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

                let merge = NoteLibraryMerge.merge(baseline: persistedNotes, local: notes, disk: diskNotes, removingFolder: folderID)
                let newNotes = merge.notes
                let encodedFolders = try encoder.encode(newFolders)
                let encodedNotes = try encoder.encode(newNotes)
                try LibraryFileTransaction.replace(notesData: encodedNotes, foldersData: encodedFolders,
                                                   notesURL: fileURL, foldersURL: foldersURL)
                try? CloudMirrorStore.publish(notesData: encodedNotes, foldersData: encodedFolders)
                return (newFolders, newNotes, merge.hasTextConflict)
            }
            folders = updatedFolders
            persistedFolders = updatedFolders
            notes = updatedNotes
            persistedNotes = updatedNotes
            persistenceGeneration += 1
            if selectedFolderID == folderID {
                selectRoot(sidebarRoot)
            }
            normalizeSelection()
            updateDockBadge()
            WidgetReloader.reload()
            if hadConflict {
                persistenceError = VellemLanguage.text("A note changed in another app. A conflict copy was created to preserve the edits.")
            }
        } catch {
            persistenceError = VellemLanguage.format("Could not delete the folder: %@", error.localizedDescription)
        }
    }

    func moveNote(_ noteID: Note.ID, toFolder folderID: Folder.ID?) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        guard notes[index].folderID != folderID else { return }
        if let folderID, !folders.contains(where: { $0.id == folderID }) { return }
        var moved = notes.remove(at: index)
        if InboxAgent.origin(of: moved) == nil, let originalAgent = agent(for: moved) {
            moved.sourceApp = originalAgent.rawValue
        }
        moved.folderID = folderID
        moved.updatedAt = .now
        notes.insert(moved, at: 0)
        normalizeSelection()
        save()
    }

    private func sortFolders() {
        folders.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Folder persistence

    private func loadFolders() {
        guard FileManager.default.fileExists(atPath: foldersURL.path) else { return }
        do {
            let loaded = try VellemLibraryValidation.uniqueIDs(decoder.decode([Folder].self, from: Data(contentsOf: foldersURL)), kind: "folders")
            folders = loaded
            persistedFolders = loaded
            sortFolders()
            ensureSmartFolders()
            if let selectedFolderID, !folders.contains(where: { $0.id == selectedFolderID }) {
                selectRoot(sidebarRoot)
            }
        } catch {
            persistenceError = VellemLanguage.format("Could not read folders: %@", error.localizedDescription)
        }
    }

    @discardableResult
    private func saveFolders() -> Bool {
        do {
            let merged = try LibraryWriteLock.withLock(in: foldersURL.deletingLastPathComponent()) {
                let disk = FileManager.default.fileExists(atPath: foldersURL.path)
                    ? try VellemLibraryValidation.uniqueIDs(decoder.decode([Folder].self, from: Data(contentsOf: foldersURL)), kind: "folders") : []
                let baseline = Dictionary(uniqueKeysWithValues: persistedFolders.map { ($0.id, $0) })
                let current = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
                var combined = Dictionary(uniqueKeysWithValues: disk.map { ($0.id, $0) })
                for id in baseline.keys where current[id] == nil { combined.removeValue(forKey: id) }
                for folder in folders where baseline[folder.id] != folder { combined[folder.id] = folder }
                let result = combined.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                let data = try encoder.encode(result)
                try data.write(to: foldersURL, options: [.atomic])
                try? CloudMirrorStore.publish(foldersData: data)
                return result
            }
            folders = merged
            persistedFolders = merged
            return true
        } catch {
            persistenceError = VellemLanguage.format("Could not save folders: %@", error.localizedDescription)
            return false
        }
    }

    private func startWatchingFoldersFile() {
        if !FileManager.default.fileExists(atPath: foldersURL.path) {
            try? FileManager.default.createDirectory(at: foldersURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: foldersURL.path, contents: Data("[]".utf8))
        }
        attachFoldersWatcher()
    }

    private func attachFoldersWatcher() {
        foldersWatcher?.cancel()
        let fd = open(foldersURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename, .revoke],
            queue: .main
        )
        source.setEventHandler { [weak self, weak source] in
            guard let self, let source else { return }
            let flags = source.data
            if flags.contains(.delete) || flags.contains(.rename) || flags.contains(.revoke) {
                source.cancel()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.attachFoldersWatcher()
                    self?.scheduleFoldersReload()
                }
            } else {
                self.scheduleFoldersReload()
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        foldersWatcher = source
    }

    private func scheduleFoldersReload() {
        foldersReloadDebounce?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.loadFolders()
        }
        foldersReloadDebounce = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: task)
    }

    // MARK: - External-note event watching

    private func startWatchingExternalEvents() {
        if !FileManager.default.fileExists(atPath: ExternalNoteEvent.eventURL.path) {
            try? FileManager.default.createDirectory(
                at: ExternalNoteEvent.eventURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            FileManager.default.createFile(atPath: ExternalNoteEvent.eventURL.path, contents: Data())
        }
        attachExternalEventWatcher()
    }

    private func attachExternalEventWatcher() {
        externalEventWatcher?.cancel()
        let fd = open(ExternalNoteEvent.eventURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename, .revoke],
            queue: .main
        )
        source.setEventHandler { [weak self, weak source] in
            guard let self, let source else { return }
            let flags = source.data
            if flags.contains(.delete) || flags.contains(.rename) || flags.contains(.revoke) {
                source.cancel()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.attachExternalEventWatcher()
                    self?.scheduleExternalEventReload()
                }
            } else {
                self.scheduleExternalEventReload()
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        externalEventWatcher = source
    }

    private func scheduleExternalEventReload() {
        externalEventDebounce?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.handleLatestExternalNoteEvent()
        }
        externalEventDebounce = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: task)
    }

    private func handleLatestExternalNoteEvent() {
        guard let event = ExternalNoteEvent.latestCreated() else {
            Task { @MainActor [weak self] in
                await self?.reloadFromDisk()
                self?.loadFolders()
                WidgetReloader.reload()
            }
            return
        }
        appendNotificationDiagnostic("external event file note=\(event.noteID.uuidString)")
        handleExternalNoteCreated(noteID: event.noteID, source: event.source)
    }

    // MARK: - External-change file watching

    private func startWatchingFile() {
        // Ensure the file exists so open() succeeds.
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: fileURL.path, contents: Data("[]".utf8))
        }
        attachWatcher()
    }

    private func attachWatcher() {
        fileWatcher?.cancel()
        let fd = open(fileURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename, .revoke],
            queue: .main
        )
        source.setEventHandler { [weak self, weak source] in
            guard let self, let source else { return }
            let flags = source.data
            if flags.contains(.delete) || flags.contains(.rename) || flags.contains(.revoke) {
                // Atomic writes replace the file; re-attach to the new inode after a tick.
                source.cancel()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.attachWatcher()
                    self?.scheduleReload()
                }
            } else {
                self.scheduleReload()
            }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        fileWatcher = source
    }

    private func scheduleReload() {
        reloadDebounce?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.reloadIfChanged()
        }
        reloadDebounce = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: task)
    }

    private func reloadIfChanged() {
        let url = fileURL
        let generation = persistenceGeneration
        Task.detached(priority: .utility) { [weak self] in
            do {
                let data = try Data(contentsOf: url)
                let loaded = try VellemLibraryValidation.uniqueIDs(JSONDecoder().decode([Note].self, from: data), kind: "notes")
                    .sorted { $0.updatedAt > $1.updatedAt }
                await MainActor.run { [weak self] in
                    guard let self, generation == self.persistenceGeneration else { return }
                    self.libraryUnavailable = false
                    guard loaded != self.notes else { return }
                    let existingNoteIDs = Set(self.notes.map(\.id))
                    let externalNewNotes = loaded.filter { !existingNoteIDs.contains($0.id) }
                    self.applyLoadedNotes(loaded)
                    for note in externalNewNotes {
                        self.notifyExternalNewNote(note, source: note.sourceApp ?? "MCP")
                    }
                }
            } catch {
                // Likely mid-write; the next event will retry.
            }
        }
    }

    func handleExternalNoteCreated(noteID: Note.ID, source: String?) {
        appendNotificationDiagnostic("handleExternalNoteCreated note=\(noteID.uuidString)")
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.reloadFromDisk()
            if let note = self.notesByID[noteID] {
                self.notifyExternalNewNote(note, source: source ?? note.sourceApp ?? "MCP")
                return
            }
            try? await Task.sleep(for: .milliseconds(250))
            await self.reloadFromDisk()
            if let note = self.notesByID[noteID] {
                self.notifyExternalNewNote(note, source: source ?? note.sourceApp ?? "MCP")
            }
        }
    }

    private func reloadFromDisk() async {
        let url = fileURL
        let generation = persistenceGeneration
        do {
            let data = try await Task.detached(priority: .utility) {
                try Data(contentsOf: url)
            }.value
            let loaded = try VellemLibraryValidation.uniqueIDs(JSONDecoder().decode([Note].self, from: data), kind: "notes")
                .sorted { $0.updatedAt > $1.updatedAt }
            guard generation == persistenceGeneration else { return }
            libraryUnavailable = false
            guard loaded != notes else { return }
            applyLoadedNotes(loaded)
        } catch {
            // Likely mid-write; the next event will retry.
        }
    }

    private func applyLoadedNotes(_ loaded: [Note]) {
        let existingCount = notes.count
        notes = loaded
        persistedNotes = loaded
        normalizeSelection()
        updateDockBadge()
        WidgetReloader.reload()
        if loaded.count < existingCount {
            pruneEmbeddingCache(keeping: Set(loaded.map(\.id)))
        }
    }

    private func notifyExternalNewNote(_ note: Note, source: String) {
        guard notifiedExternalNoteIDs.insert(note.id).inserted else { return }
        // Cap size to avoid unbounded growth during long sessions.
        if notifiedExternalNoteIDs.count > 500 { notifiedExternalNoteIDs.removeAll() }
        appendNotificationDiagnostic("notifyExternalNewNote note=\(note.id.uuidString)")
        NoteNotifications.notifyNewNote(note, source: source)
    }

    private func appendNotificationDiagnostic(_ message: String) {
        let line = "\(Date()) \(message)\n"
        let url = AppGroup.containerURL.appending(path: "notification-debug.log")
        // File I/O on a background thread — diagnostics must never block the main thread.
        Task.detached(priority: .background) {
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: url.path),
                   let handle = try? FileHandle(forWritingTo: url) {
                    try handle.seekToEnd()
                    if let data = line.data(using: .utf8) {
                        try handle.write(contentsOf: data)
                    }
                    try handle.close()
                } else {
                    try line.write(to: url, atomically: true, encoding: .utf8)
                }
            } catch {
                // Diagnostics should never affect note capture.
            }
        }
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

    var inboxNotes: [Note] {
        notes.filter { !$0.isDailyNote }
    }

    var inboxUnreadCount: Int {
        inboxNotes.reduce(0) { $0 + ($1.isRead ? 0 : 1) }
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

        return "No folder"
    }

    func noteReference(for note: Note) -> String {
        let folder = note.folderID.flatMap { folderID in
            folders.first { $0.id == folderID }
        }
        var lines = [
            "Vellem note reference",
            "id: \(note.id.uuidString)",
            "path: \(notePath(for: note, folder: folder))",
            "url: vellem://note/\(note.id.uuidString)",
            "mcp: get_note {\"id\":\"\(note.id.uuidString)\"}"
        ]

        if let folder {
            lines.insert("folder_id: \(folder.id.uuidString)", at: 3)
        }

        return lines.joined(separator: "\n")
    }

    private func notePath(for note: Note, folder: Folder?) -> String {
        let location: String
        if note.isDailyNote {
            location = "Today"
        } else if let folder {
            location = folder.displayPath
        } else if note.isFromCodex,
                  let folder = folders.first(where: { $0.kind == .smartCodex }) {
            location = folder.displayPath
        } else if note.isFromClaude,
                  let folder = folders.first(where: { $0.kind == .smartClaude }) {
            location = folder.displayPath
        } else {
            location = "Inbox"
        }

        return ["Vellem", location, note.title]
            .map { $0.replacingOccurrences(of: "/", with: "／") }
            .joined(separator: " / ")
    }

    func noteMatchesDisplay(_ note: Note, in folder: Folder) -> Bool {
        if folder.kind == .regular { return note.folderID == folder.id }
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

    func agent(for note: Note) -> InboxAgent? {
        if let origin = InboxAgent.origin(of: note) { return origin }
        guard note.sourceApp == nil || note.sourceApp == "MCP",
              let id = note.folderID else { return nil }
        switch folders.first(where: { $0.id == id })?.kind {
        case .smartClaude: return .claude
        case .smartCodex: return .codex
        default: return nil
        }
    }

    var displayedNotes: [Note] {
        if let id = selectedFolderID, let folder = folders.first(where: { $0.id == id && !$0.isSmart }) {
            return notesForDisplay(in: folder)
        }
        return notes.filter(mailboxFilter(for: sidebarRoot))
    }

    func hasUnread(in root: SidebarMailbox) -> Bool {
        let matches = mailboxFilter(for: root)
        return notes.contains { !$0.isRead && matches($0) }
    }

    private func mailboxFilter(for root: SidebarMailbox) -> (Note) -> Bool {
        switch root {
        case .inbox: return { !$0.isDailyNote }
        case .today: return { Calendar.current.isDateInToday($0.createdAt) }
        case .folders, .captures, .agent:
            let filed = Set(folders.filter { !$0.isSmart && (root == .folders || $0.mailbox == root.folderKey) }.map(\.id))
            if case .agent(let origin) = root {
                return { !$0.isDailyNote && (self.agent(for: $0) == origin || $0.folderID.map(filed.contains) == true) }
            }
            let captureID = root == .captures ? servicesFolderID : nil
            return { note in note.folderID.map { $0 == captureID || filed.contains($0) } == true }
        }
    }

    func selectRoot(_ root: SidebarMailbox) {
        sidebarRoot = root
        selectedFolderID = nil
        if case .agent(let agent) = root { inboxAgent = agent } else { inboxAgent = nil }
        isInboxSelected = root == .inbox || inboxAgent != nil
        isTodaySelected = root == .today
        selectedNoteID = displayedNotes.first?.id
        if let selectedNoteID { markRead(selectedNoteID) }
    }

    func selectToday() { selectRoot(.today) }

    func selectInbox(agent: InboxAgent? = nil) { selectRoot(agent.map(SidebarMailbox.agent) ?? .inbox) }

    func selectNote(_ noteID: Note.ID, inToday: Bool = false, inFolder folderID: Folder.ID? = nil) {
        selectedNoteID = noteID
        selectedFolderID = folderID
        isInboxSelected = folderID == nil && !inToday && isInboxSelected
        isTodaySelected = inToday
        markRead(noteID)
    }

    func selectFolder(_ folderID: Folder.ID, from root: SidebarMailbox? = nil) {
        guard let folder = folders.first(where: { $0.id == folderID }) else { return }
        if folder.isSmart {
            selectRoot(SidebarMailbox(folder: folder))
            return
        }
        sidebarRoot = root ?? SidebarMailbox(folder: folder)
        selectedFolderID = folderID
        isInboxSelected = false
        isTodaySelected = false
        selectedNoteID = firstNoteID(inFolderID: folderID)
        if let selectedNoteID {
            markRead(selectedNoteID)
        }
    }

    func load() {
        do {
            migrateLegacyNotes()
            let data = try Data(contentsOf: fileURL)
            notes = try VellemLibraryValidation.uniqueIDs(decoder.decode([Note].self, from: data), kind: "notes")
                .sorted { $0.updatedAt > $1.updatedAt }
            libraryUnavailable = false
            persistedNotes = notes
            selectedNoteID = firstInboxNoteID()
            updateDockBadge()
        } catch {
            notes = []
            selectedNoteID = nil
            if FileManager.default.fileExists(atPath: fileURL.path) {
                libraryUnavailable = true
                persistenceError = VellemLanguage.format("Could not read notes: %@", error.localizedDescription)
            }
            updateDockBadge()
        }
    }

    func replaceLibrary(notes importedNotes: [Note], folders importedFolders: [Folder]) throws {
        let sortedNotes = importedNotes.sorted { $0.updatedAt > $1.updatedAt }
        let preparedFolders = Self.normalizedSystemFolders(importedFolders)

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: foldersURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try LibraryWriteLock.withLock(in: fileURL.deletingLastPathComponent()) {
            let notesData = try encoder.encode(sortedNotes)
            let foldersData = try encoder.encode(preparedFolders)
            try LibraryFileTransaction.replace(notesData: notesData, foldersData: foldersData,
                                               notesURL: fileURL, foldersURL: foldersURL)
            try? CloudMirrorStore.publish(notesData: notesData, foldersData: foldersData)
        }

        folders = preparedFolders
        notes = sortedNotes
        persistedNotes = sortedNotes
        persistedFolders = preparedFolders
        persistenceGeneration += 1
        libraryUnavailable = false
        selectedFolderID = nil
        sidebarRoot = .inbox
        inboxAgent = nil
        isInboxSelected = true
        isTodaySelected = false
        selectedNoteID = firstInboxNoteID()
        normalizeSelection()
        updateDockBadge()
        WidgetReloader.reload()
        pruneEmbeddingCache(keeping: Set(sortedNotes.map(\.id)))
    }

    func markRead(_ noteID: Note.ID) {
        setReadState(true, for: noteID)
    }

    func markUnread(_ noteID: Note.ID) {
        setReadState(false, for: noteID)
    }

    private func setReadState(_ isRead: Bool, for noteID: Note.ID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }),
              notes[index].isRead != isRead else {
            return
        }
        notes[index].isRead = isRead
        save()
    }

    func delete(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        normalizeSelection()
        save()
        pruneEmbeddingCache(keeping: Set(notes.map(\.id)))
    }

    private func normalizeSelection() {
        let candidates = displayedNotes
        if let selectedNoteID, candidates.contains(where: { $0.id == selectedNoteID }) { return }
        selectedNoteID = candidates.first?.id
    }

    private func firstInboxNoteID() -> Note.ID? { inboxNotes.first?.id }

    private func firstNoteID(inFolderID folderID: Folder.ID) -> Note.ID? {
        guard let folder = folders.first(where: { $0.id == folderID }) else { return nil }
        return notes.first { noteMatchesDisplay($0, in: folder) }?.id
    }

    @discardableResult
    private func save() -> Bool {
        do {
            var hadTextConflict = false
            let merged = try LibraryWriteLock.withLock(in: fileURL.deletingLastPathComponent()) {
                let disk = FileManager.default.fileExists(atPath: fileURL.path)
                    ? try VellemLibraryValidation.uniqueIDs(decoder.decode([Note].self, from: Data(contentsOf: fileURL)), kind: "notes") : []
                let result = NoteLibraryMerge.merge(baseline: persistedNotes, local: notes, disk: disk)
                hadTextConflict = result.hasTextConflict
                let data = try encoder.encode(result.notes)
                try data.write(to: fileURL, options: [.atomic])
                let foldersData = try? Data(contentsOf: foldersURL)
                try? CloudMirrorStore.publish(notesData: data, foldersData: foldersData)
                return result.notes
            }
            notes = merged
            persistedNotes = merged
            persistenceGeneration += 1
            if hadTextConflict {
                persistenceError = VellemLanguage.text("A note changed in another app while you were editing. A conflict copy was created to preserve the edits.")
            }
            updateDockBadge()
            WidgetReloader.reload()
            return true
        } catch {
            persistenceError = VellemLanguage.format("Could not save notes: %@", error.localizedDescription)
            return false
        }
    }

    private func updateDockBadge() {
        let count = inboxUnreadCount
        NSApp.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
    }

    private func migrateLegacyNotes() {
        guard VellemStorageEnvironment.isolatedDirectory == nil else { return }
        guard fileURL == AppGroup.notesURL else {
            return
        }

        do {
            try LibraryWriteLock.withLock(in: fileURL.deletingLastPathComponent()) {
                // Legacy data is imported only when no current library exists.
                // Re-importing on every launch would resurrect deleted notes.
                guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
                var mergedNotes: [Note] = []
                var existingIDs = Set(mergedNotes.map(\.id))
                var changed = false
                for sourceURL in [AppGroup.applicationSupportNotesURL, AppGroup.legacyNotesURL] {
                    for note in fileNotes(at: sourceURL) where !existingIDs.contains(note.id) {
                        mergedNotes.append(note)
                        existingIDs.insert(note.id)
                        changed = true
                    }
                }
                guard changed else { return }
                let data = try encoder.encode(mergedNotes.sorted { $0.updatedAt > $1.updatedAt })
                try data.write(to: fileURL, options: [.atomic])
            }
        } catch {
            persistenceError = VellemLanguage.format("Could not migrate notes: %@", error.localizedDescription)
        }
    }

    private func fileNotes(at url: URL) -> [Note] {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let notes = try? decoder.decode([Note].self, from: data) else {
            return []
        }

        return notes
    }
}
