import Foundation

/// Reads and writes the same notes.json file the Vellem app uses, via the
/// shared App Group container. Uses NSFileCoordinator for safe concurrent access
/// with the main app.
final class NotesFileStore {
    private let fileURL: URL
    private let foldersURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let container = home.appending(path: "Library/Group Containers/MKAFV9VL9V.com.adriendonot.Vellem")
        self.fileURL = container.appending(path: "notes.json")
        self.foldersURL = container.appending(path: "folders.json")
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    // MARK: - Public API

    func addNote(text: String, generatedTitle: String? = nil, folderID: UUID? = nil) throws -> Note {
        var notes = try load()
        let resolvedFolderID = try resolveFolderID(folderID)
        let note = Note(
            text: text,
            generatedTitle: generatedTitle,
            kind: .regular,
            sourceApp: "Claude (MCP)",
            sourceURL: nil,
            folderID: resolvedFolderID
        )
        notes.insert(note, at: 0)
        try save(notes)
        ExternalNoteEvent.postCreated(noteID: note.id, source: "Claude (MCP)")
        return note
    }

    private func resolveFolderID(_ folderID: UUID?) throws -> UUID? {
        guard let folderID else { return nil }
        let folders = try loadFolders()
        guard folders.contains(where: { $0.id == folderID }) else {
            throw MCPError.notFound("Folder \(folderID) not found.")
        }
        return folderID
    }

    func appendToDaily(text: String) throws -> Note {
        var notes = try load()
        let now = Date()
        let cal = Calendar.current

        if let index = notes.firstIndex(where: { $0.kind == .daily && cal.isDate($0.createdAt, inSameDayAs: now) }) {
            var updated = notes[index]
            let separator = updated.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\n\n"
            updated.text += separator + text
            updated.updatedAt = now
            notes[index] = updated
            notes.sort { $0.updatedAt > $1.updatedAt }
            try save(notes)
            return updated
        }

        let title = dailyTitle(for: now)
        let note = Note(
            text: "# \(title)\n\n" + text,
            generatedTitle: title,
            kind: .daily,
            sourceApp: "Claude (MCP)",
            sourceURL: nil,
            createdAt: now,
            updatedAt: now
        )
        notes.insert(note, at: 0)
        try save(notes)
        ExternalNoteEvent.postCreated(noteID: note.id, source: "Claude (MCP)")
        return note
    }

    func listNotes(limit: Int) throws -> [Note] {
        let notes = try load()
        return Array(notes.prefix(max(1, limit)))
    }

    func searchNotes(query: String, limit: Int) throws -> [Note] {
        let notes = try load()
        let q = query.lowercased()
        let filtered = notes.filter { n in
            n.title.lowercased().contains(q) || n.text.lowercased().contains(q)
        }
        return Array(filtered.prefix(max(1, limit)))
    }

    func getNote(id: UUID) throws -> Note? {
        let notes = try load()
        return notes.first { $0.id == id }
    }

    func updateNote(id: UUID, text: String) throws -> Note {
        var notes = try load()
        guard let index = notes.firstIndex(where: { $0.id == id }) else {
            throw MCPError.notFound("Note \(id) not found.")
        }
        notes[index].text = text
        notes[index].updatedAt = Date()
        let updated = notes[index]
        notes.sort { $0.updatedAt > $1.updatedAt }
        try save(notes)
        return updated
    }

    func deleteNote(id: UUID) throws {
        var notes = try load()
        guard let index = notes.firstIndex(where: { $0.id == id }) else {
            throw MCPError.notFound("Note \(id) not found.")
        }
        notes.remove(at: index)
        try save(notes)
    }

    // MARK: - Folder API

    func listFolders() throws -> [Folder] {
        try loadFolders().sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func findFolder(byName name: String) throws -> Folder? {
        let target = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return try loadFolders().first { $0.name.lowercased() == target }
    }

    func createFolder(name: String) throws -> Folder {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw MCPError.invalidArguments("Folder name cannot be empty.") }
        var folders = try loadFolders()
        if let existing = folders.first(where: { $0.name.lowercased() == cleaned.lowercased() }) {
            return existing
        }
        let folder = Folder(name: cleaned)
        folders.append(folder)
        try saveFolders(folders)
        return folder
    }

    func setFolderColor(id: UUID, color: String?) throws -> Folder {
        var folders = try loadFolders()
        guard let index = folders.firstIndex(where: { $0.id == id }) else {
            throw MCPError.notFound("Folder \(id) not found.")
        }
        folders[index].color = color
        try saveFolders(folders)
        return folders[index]
    }

    func deleteFolder(id: UUID) throws {
        var folders = try loadFolders()
        guard let index = folders.firstIndex(where: { $0.id == id }) else {
            throw MCPError.notFound("Folder \(id) not found.")
        }
        guard !folders[index].isSmart else {
            throw MCPError.invalidArguments("Folder \"\(folders[index].name)\" is a smart folder and cannot be deleted.")
        }
        folders.remove(at: index)
        try saveFolders(folders)

        var notes = try load()
        var changed = false
        for i in notes.indices where notes[i].folderID == id {
            notes[i].folderID = nil
            changed = true
        }
        if changed { try save(notes) }
    }

    func moveNote(id: UUID, toFolder folderID: UUID?) throws -> Note {
        let resolved = try resolveFolderID(folderID)
        var notes = try load()
        guard let index = notes.firstIndex(where: { $0.id == id }) else {
            throw MCPError.notFound("Note \(id) not found.")
        }
        notes[index].folderID = resolved
        notes[index].updatedAt = Date()
        let updated = notes[index]
        notes.sort { $0.updatedAt > $1.updatedAt }
        try save(notes)
        return updated
    }

    private func loadFolders() throws -> [Folder] {
        try ensureFoldersDirectory()
        if !FileManager.default.fileExists(atPath: foldersURL.path) {
            return []
        }
        var outError: NSError?
        var result: [Folder] = []
        var ioError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(readingItemAt: foldersURL, options: [], error: &outError) { url in
            do {
                let data = try Data(contentsOf: url)
                if data.isEmpty { result = []; return }
                result = try decoder.decode([Folder].self, from: data)
            } catch {
                ioError = error
            }
        }
        if let outError { throw MCPError.io("Folder read coordination failed: \(outError.localizedDescription)") }
        if let ioError { throw MCPError.io("Folder read failed: \(ioError.localizedDescription)") }
        return result
    }

    private func saveFolders(_ folders: [Folder]) throws {
        try ensureFoldersDirectory()
        var outError: NSError?
        var ioError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: foldersURL, options: .forReplacing, error: &outError) { url in
            do {
                let data = try encoder.encode(folders)
                try data.write(to: url, options: [.atomic])
            } catch {
                ioError = error
            }
        }
        if let outError { throw MCPError.io("Folder write coordination failed: \(outError.localizedDescription)") }
        if let ioError { throw MCPError.io("Folder write failed: \(ioError.localizedDescription)") }
    }

    private func ensureFoldersDirectory() throws {
        let dir = foldersURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    // MARK: - Load/Save (coordinated)

    private func load() throws -> [Note] {
        try ensureDirectory()
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            return []
        }

        var outError: NSError?
        var result: [Note] = []
        var ioError: Error?

        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(readingItemAt: fileURL, options: [], error: &outError) { url in
            do {
                let data = try Data(contentsOf: url)
                let notes = try decoder.decode([Note].self, from: data)
                result = notes.sorted { $0.updatedAt > $1.updatedAt }
            } catch {
                ioError = error
            }
        }
        if let outError { throw MCPError.io("Read coordination failed: \(outError.localizedDescription)") }
        if let ioError { throw MCPError.io("Read failed: \(ioError.localizedDescription)") }
        return result
    }

    private func save(_ notes: [Note]) throws {
        try ensureDirectory()
        var outError: NSError?
        var ioError: Error?

        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: fileURL, options: .forReplacing, error: &outError) { url in
            do {
                let data = try encoder.encode(notes)
                try data.write(to: url, options: [.atomic])
            } catch {
                ioError = error
            }
        }
        if let outError { throw MCPError.io("Write coordination failed: \(outError.localizedDescription)") }
        if let ioError { throw MCPError.io("Write failed: \(ioError.localizedDescription)") }
    }

    private func ensureDirectory() throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func dailyTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "Today, \(formatter.string(from: date))"
    }
}
