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
    @Published var isTodaySelected = false

    var viewerNote: Note? {
        guard let viewerNoteID else { return nil }
        return notes.first { $0.id == viewerNoteID }
    }

    var unreadCount: Int {
        notes.filter { !$0.isRead }.count
    }

    private let fileURL: URL
    private let foldersURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let editor = FoundationNoteEditor()
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
        load()
        loadFolders()
        ensureSmartFolders()
        startWatchingFile()
        startWatchingFoldersFile()
        startWatchingExternalEvents()
        WidgetReloader.reload()
        Task {
            await generateTitles()
        }
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

    private func ensureSmartFolders() {
        var changed = false
        changed = ensureSystemFolder(name: "Claude", color: FolderColor.red.rawValue, kind: .smartClaude) || changed
        changed = ensureSystemFolder(name: "Codex", color: FolderColor.blue.rawValue, kind: .smartCodex) || changed
        changed = ensureSystemFolder(name: "Prompt Library", color: FolderColor.purple.rawValue, kind: .smartPromptLibrary) || changed
        changed = ensureSystemFolder(name: "Services", color: FolderColor.green.rawValue, kind: .smartServices) || changed

        if changed {
            sortFolders()
            saveFolders()
        }
    }

    private func ensureSystemFolder(name: String, color: String, kind: FolderKind) -> Bool {
        if let index = folders.firstIndex(where: { $0.kind == kind }) {
            var changed = false
            if folders[index].name != name {
                folders[index].name = name
                changed = true
            }
            if folders[index].color != color {
                folders[index].color = color
                changed = true
            }
            return changed
        }

        if let index = folders.firstIndex(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            folders[index].kind = kind
            folders[index].name = name
            folders[index].color = color
            return true
        }

        folders.append(Folder(name: name, color: color, kind: kind))
        return true
    }

    @discardableResult
    func captureFromServices(text: String, source: CaptureSource? = nil) -> Note? {
        guard let note = create(text: text, source: source) else { return nil }
        if let folderID = servicesFolderID {
            moveNote(note.id, toFolder: folderID)
        }
        let deliveredNote = notes.first { $0.id == note.id } ?? note
        NoteNotifications.notifyNewNote(deliveredNote, source: source?.appName ?? "Services")
        return deliveredNote
    }

    @discardableResult
    func createFolder(name: String) -> Folder {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = cleaned.isEmpty ? "New folder" : cleaned
        let folder = Folder(name: finalName)
        folders.append(folder)
        sortFolders()
        saveFolders()
        return folder
    }

    func setFolderColor(_ folderID: Folder.ID, color: FolderColor?) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        folders[index].color = color?.rawValue
        saveFolders()
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
        folders.removeAll { $0.id == folderID }
        for index in notes.indices where notes[index].folderID == folderID {
            notes[index].folderID = nil
        }
        if selectedFolderID == folderID { selectedFolderID = nil }
        normalizeSelection()
        saveFolders()
        save()
    }

    func moveNote(_ noteID: Note.ID, toFolder folderID: Folder.ID?) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        guard notes[index].folderID != folderID else { return }
        if let folderID, !folders.contains(where: { $0.id == folderID }) { return }
        notes[index].folderID = folderID
        notes[index].updatedAt = .now
        notes.sort { $0.updatedAt > $1.updatedAt }
        normalizeSelection()
        save()
    }

    private func sortFolders() {
        folders.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Folder persistence

    private func loadFolders() {
        guard FileManager.default.fileExists(atPath: foldersURL.path),
              let data = try? Data(contentsOf: foldersURL),
              let loaded = try? decoder.decode([Folder].self, from: data) else {
            folders = []
            return
        }
        folders = loaded
        sortFolders()
        ensureSmartFolders()
    }

    private func saveFolders() {
        do {
            try FileManager.default.createDirectory(
                at: foldersURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(folders)
            try data.write(to: foldersURL, options: [.atomic])
        } catch {
            assertionFailure("Could not save folders: \(error)")
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
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = source.data
            if flags.contains(.delete) || flags.contains(.rename) || flags.contains(.revoke) {
                source.cancel()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.attachFoldersWatcher()
                    self.scheduleFoldersReload()
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
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = source.data
            if flags.contains(.delete) || flags.contains(.rename) || flags.contains(.revoke) {
                source.cancel()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.attachExternalEventWatcher()
                    self.scheduleExternalEventReload()
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
        guard let event = ExternalNoteEvent.latestCreated() else { return }
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
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = source.data
            if flags.contains(.delete) || flags.contains(.rename) || flags.contains(.revoke) {
                // Atomic writes replace the file; re-attach to the new inode after a tick.
                source.cancel()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.attachWatcher()
                    self.scheduleReload()
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
        do {
            let data = try Data(contentsOf: fileURL)
            let loaded = try decoder.decode([Note].self, from: data)
                .sorted { $0.updatedAt > $1.updatedAt }
            guard loaded != notes else { return }
            let existingNoteIDs = Set(notes.map(\.id))
            let externalNewNotes = loaded.filter { !existingNoteIDs.contains($0.id) }
            applyLoadedNotes(loaded)
            for note in externalNewNotes {
                notifyExternalNewNote(note, source: note.sourceApp ?? "MCP")
            }
        } catch {
            // Likely mid-write; the next event will retry.
        }
    }

    func handleExternalNoteCreated(noteID: Note.ID, source: String?) {
        appendNotificationDiagnostic("handleExternalNoteCreated note=\(noteID.uuidString)")
        reloadFromDisk()
        if let note = notes.first(where: { $0.id == noteID }) {
            notifyExternalNewNote(note, source: source ?? note.sourceApp ?? "MCP")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else { return }
            self.reloadFromDisk()
            if let note = self.notes.first(where: { $0.id == noteID }) {
                self.notifyExternalNewNote(note, source: source ?? note.sourceApp ?? "MCP")
            }
        }
    }

    private func reloadFromDisk() {
        do {
            let data = try Data(contentsOf: fileURL)
            let loaded = try decoder.decode([Note].self, from: data)
                .sorted { $0.updatedAt > $1.updatedAt }
            guard loaded != notes else { return }
            applyLoadedNotes(loaded)
        } catch {
            // Likely mid-write; the next event will retry.
        }
    }

    private func applyLoadedNotes(_ loaded: [Note]) {
        notes = loaded
        normalizeSelection()
        updateDockBadge()
        WidgetReloader.reload()
    }

    private func notifyExternalNewNote(_ note: Note, source: String) {
        guard notifiedExternalNoteIDs.insert(note.id).inserted else { return }
        appendNotificationDiagnostic("notifyExternalNewNote note=\(note.id.uuidString)")
        NoteNotifications.notifyNewNote(note, source: source)
    }

    private func appendNotificationDiagnostic(_ message: String) {
        let line = "\(Date()) \(message)\n"
        let url = AppGroup.containerURL.appending(path: "notification-debug.log")
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

    var selectedNote: Note? {
        guard let selectedNoteID else { return notes.first }
        return notes.first { $0.id == selectedNoteID }
    }

    func notesForDisplay(in folder: Folder) -> [Note] {
        notes.filter { noteMatchesDisplay($0, in: folder) }
    }

    func noteCountForDisplay(in folder: Folder) -> Int {
        notesForDisplay(in: folder).count
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

    func selectToday() {
        isTodaySelected = true
        selectedFolderID = nil
        selectedNoteID = firstTodayNoteID()
        if let selectedNoteID {
            markRead(selectedNoteID)
        }
    }

    func selectNote(_ noteID: Note.ID, inToday: Bool = false, inFolder folderID: Folder.ID? = nil) {
        selectedNoteID = noteID
        selectedFolderID = folderID
        isTodaySelected = inToday
        markRead(noteID)
    }

    func selectFolder(_ folderID: Folder.ID) {
        selectedFolderID = folderID
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
            notes = try decoder.decode([Note].self, from: data)
                .sorted { $0.updatedAt > $1.updatedAt }
            selectedNoteID = notes.first?.id
            updateDockBadge()
        } catch {
            notes = []
            selectedNoteID = nil
            updateDockBadge()
        }
    }

    @discardableResult
    func create(text: String, source: CaptureSource? = nil) -> Note? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        let note = Note(text: cleaned, sourceApp: source?.appName, sourceURL: source?.url, isRead: source == nil)
        notes.insert(note, at: 0)
        selectedNoteID = note.id
        isTodaySelected = false
        save()
        Task {
            await formatNoteByDefault(noteID: note.id, originalText: cleaned, preservesTitle: false)
        }
        return note
    }

    @discardableResult
    func createDraft() -> Note {
        let note = Note(text: "", isRead: true)
        notes.insert(note, at: 0)
        selectedNoteID = note.id
        isTodaySelected = false
        save()
        return note
    }

    func update(_ note: Note, text: String, regenerateTitle: Bool = false) {
        update(noteID: note.id, text: text, regenerateTitle: regenerateTitle)
    }

    func update(noteID: Note.ID, text: String, regenerateTitle: Bool = false) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        guard notes[index].text != text else { return }

        var updated = notes[index]
        updated.text = text
        updated.updatedAt = .now
        notes[index] = updated
        notes.sort { $0.updatedAt > $1.updatedAt }
        selectedNoteID = updated.id
        save()

        if regenerateTitle {
            Task {
                await generateTitle(for: updated.id, text: text)
            }
        }
    }

    func updateTitle(_ title: String, for noteID: Note.ID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[index].generatedTitle = cleanTitle(title)
        save()
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

    func formatAfterEditing(noteID: Note.ID, originalText: String) {
        Task {
            await formatNoteByDefault(noteID: noteID, originalText: originalText, preservesTitle: false)
        }
    }

    func delete(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        normalizeSelection()
        save()
    }

    @discardableResult
    func upsertDailyNote(for date: Date = .now, appending text: String? = nil, source: CaptureSource? = nil) -> Note {
        let day = Calendar.current.startOfDay(for: date)
        let title = dailyTitle(for: day)

        if let index = notes.firstIndex(where: { $0.kind == .daily && Calendar.current.isDate($0.createdAt, inSameDayAs: day) }) {
            if let text,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                notes[index].text = append(text, toDailyText: notes[index].text)
                notes[index].updatedAt = .now
                if source != nil {
                    notes[index].isRead = false
                }
            }
            if let source {
                notes[index].sourceApp = source.appName
                notes[index].sourceURL = source.url
            }
            notes[index].generatedTitle = title
            selectedNoteID = notes[index].id
            isTodaySelected = false
            notes.sort { $0.updatedAt > $1.updatedAt }
            save()
            let updatedNote = notes.first { $0.id == selectedNoteID } ?? notes[0]
            if text != nil {
                Task {
                    await formatNoteByDefault(noteID: updatedNote.id, originalText: updatedNote.text, preservesTitle: true)
                }
            }
            return notes.first { $0.id == selectedNoteID } ?? notes[0]
        }

        let note = Note(
            text: text.map { append($0, toDailyText: "") } ?? "",
            generatedTitle: title,
            kind: .daily,
            sourceApp: source?.appName,
            sourceURL: source?.url,
            createdAt: day,
            updatedAt: .now,
            isRead: source == nil
        )
        notes.insert(note, at: 0)
        selectedNoteID = note.id
        isTodaySelected = false
        save()
        if text != nil {
            Task {
                await formatNoteByDefault(noteID: note.id, originalText: note.text, preservesTitle: true)
            }
        }
        return note
    }

    private func formatNoteByDefault(noteID: Note.ID, originalText: String, preservesTitle: Bool) async {
        do {
            let formattedText = try await editor.edit(originalText, action: .format)
            guard let index = notes.firstIndex(where: { $0.id == noteID }),
                  notes[index].text == originalText else {
                return
            }

            notes[index].text = formattedText
            notes[index].updatedAt = .now
            if !preservesTitle {
                let title = try? await editor.title(for: formattedText)
                notes[index].generatedTitle = title.map(cleanTitle)
            }
            notes.sort { $0.updatedAt > $1.updatedAt }
            save()
        } catch {
            if !preservesTitle {
                await generateTitle(for: noteID, text: originalText)
            }
        }
    }

    private func generateTitles() async {
        for note in notes where note.generatedTitle == nil && !note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await generateTitle(for: note.id, text: note.text)
        }
    }

    private func generateTitle(for noteID: Note.ID, text: String) async {
        do {
            let title = try await editor.title(for: text)
            updateTitle(title, for: noteID)
        } catch {
            // Keep the readable fallback title when Foundation Models is not available.
        }
    }

    private func normalizeSelection() {
        if let selectedNoteID,
           let note = notes.first(where: { $0.id == selectedNoteID }),
           noteMatchesCurrentSelection(note) {
            return
        }

        selectedNoteID = firstNoteIDForCurrentSelection()
    }

    private func noteMatchesCurrentSelection(_ note: Note) -> Bool {
        if isTodaySelected {
            return Calendar.current.isDateInToday(note.createdAt)
        }

        if let selectedFolderID,
           let folder = folders.first(where: { $0.id == selectedFolderID }) {
            return noteMatchesDisplay(note, in: folder)
        }

        return true
    }

    private func firstNoteIDForCurrentSelection() -> Note.ID? {
        if isTodaySelected {
            return firstTodayNoteID()
        }

        if let selectedFolderID {
            return firstNoteID(inFolderID: selectedFolderID)
        }

        return notes.first?.id
    }

    private func firstTodayNoteID() -> Note.ID? {
        notes.first { Calendar.current.isDateInToday($0.createdAt) }?.id
    }

    private func firstNoteID(inFolderID folderID: Folder.ID) -> Note.ID? {
        guard let folder = folders.first(where: { $0.id == folderID }) else { return nil }
        return notes.first { noteMatchesDisplay($0, in: folder) }?.id
    }

    private func cleanTitle(_ title: String) -> String {
        let cleaned = title
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var words = cleaned
            .split(separator: " ")
            .prefix(4)
            .map(String.init)

        let trailingStopWords = [
            "a", "an", "and", "as", "at", "for", "from", "in", "of", "on", "or", "the", "to",
            "à", "au", "aux", "avec", "de", "des", "du", "en", "et", "la", "le", "les", "ou", "un", "une"
        ]

        while words.count > 3,
              let last = words.last?.lowercased(),
              trailingStopWords.contains(last) {
            words.removeLast()
        }

        return words.joined(separator: " ")
    }

    private func dailyTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return "Today, \(formatter.string(from: date))"
    }

    private func append(_ entry: String, toDailyText text: String) -> String {
        let cleaned = entry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return text }

        let time = DateFormatter.localizedString(from: .now, dateStyle: .none, timeStyle: .short)
        let block = "## \(time)\n\(cleaned)"

        let existing = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return existing.isEmpty ? block : "\(existing)\n\n\(block)"
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(notes)
            try data.write(to: fileURL, options: [.atomic])
            updateDockBadge()
            WidgetReloader.reload()
        } catch {
            assertionFailure("Could not save notes: \(error)")
        }
    }

    private func updateDockBadge() {
        let count = unreadCount
        NSApp.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
    }

    private func migrateLegacyNotes() {
        guard fileURL == AppGroup.notesURL else {
            return
        }

        do {
            var mergedNotes = fileNotes(at: fileURL)
            var existingIDs = Set(mergedNotes.map(\.id))

            for sourceURL in [AppGroup.applicationSupportNotesURL, AppGroup.legacyNotesURL] {
                for note in fileNotes(at: sourceURL) where !existingIDs.contains(note.id) {
                    mergedNotes.append(note)
                    existingIDs.insert(note.id)
                }
            }

            guard !mergedNotes.isEmpty else { return }

            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(mergedNotes.sorted { $0.updatedAt > $1.updatedAt })
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Could not migrate notes: \(error)")
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
