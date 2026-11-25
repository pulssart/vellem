import AppKit
import Foundation

enum NoteNotifications {
    static func notifyNewNote(_ note: Note, source: String) { }
}
enum WidgetReloader {
    static func reload() { }
}

@main
enum ConcurrentStoreTests {
    @MainActor
    static func main() throws {
        testAgentFolderVisibility()
        guard let directory = VellemStorageEnvironment.isolatedDirectory, CommandLine.arguments.count == 2 else {
            fatalError("Provide a Debug MCP binary and an isolated library")
        }
        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)
        let binary = CommandLine.arguments[1]
        let notesURL = directory.appending(path: "notes.json")
        let foldersURL = directory.appending(path: "folders.json")
        _ = try callMCP(binary, name: "send_output", arguments: ["text": "# Original\n\nStarting text"])
        let store = NotesStore(fileURL: notesURL, foldersURL: foldersURL)
        let original = try JSONDecoder().decode([Note].self, from: Data(contentsOf: notesURL))[0]

        let folder = store.createFolder(name: "Research")
        _ = try callMCP(binary, name: "add_note", arguments: ["text": "# Arrived from agent", "folder_id": folder.id.uuidString])
        store.deleteFolder(folder.id)
        var saved = try JSONDecoder().decode([Note].self, from: Data(contentsOf: notesURL))
        precondition(saved.contains { $0.text.contains("Arrived from agent") && $0.folderID == nil })
        let folders = try JSONDecoder().decode([Folder].self, from: Data(contentsOf: foldersURL))
        precondition(!folders.contains { $0.id == folder.id })

        var processes: [Process] = []
        for index in 0..<16 {
            let process = try startMCP(binary, name: "add_note", arguments: ["text": "# Parallel agent \(index)"])
            processes.append(process)
        }
        store.markRead(original.id)
        for process in processes {
            process.waitUntilExit()
            precondition(process.terminationStatus == 0)
        }
        saved = try JSONDecoder().decode([Note].self, from: Data(contentsOf: notesURL))
        precondition(saved.contains { $0.id == original.id && $0.text == original.text && $0.isRead })
        precondition(saved.filter { $0.text.hasPrefix("# Parallel agent ") }.count == 16)

        let replacement = Note(text: "# Imported note")
        try store.replaceLibrary(notes: [replacement], folders: [])
        saved = try JSONDecoder().decode([Note].self, from: Data(contentsOf: notesURL))
        precondition(saved.count == 1 && saved[0].id == replacement.id)
        let importedFolders = try JSONDecoder().decode([Folder].self, from: Data(contentsOf: foldersURL))
        precondition(Set(importedFolders.filter(\.isSmart).map(\.kind)) == [.smartClaude, .smartCodex, .smartServices])

        let chatFolder = store.createFolder(name: "Research", mailbox: "ChatGPT")
        let codexFolder = store.createFolder(name: "Research", mailbox: "Codex")
        _ = try callMCP(binary, name: "send_output", arguments: ["text": "Received message", "source_agent": "ChatGPT", "folder_id": chatFolder.id.uuidString])
        _ = try callMCP(binary, name: "add_note", arguments: ["text": "Routed export", "source_agent": "Codex", "folder_name": "Research"])
        let reloaded = NotesStore(fileURL: notesURL, foldersURL: foldersURL)
        reloaded.selectRoot(.agent(.codex))
        precondition(reloaded.displayedNotes.count == 1 && reloaded.displayedNotes.first?.folderID == codexFolder.id)
        reloaded.selectRoot(.agent(.chatGPT))
        precondition(reloaded.displayedNotes.count == 1 && reloaded.displayedNotes.first?.folderID == chatFolder.id)
        reloaded.selectFolder(chatFolder.id)
        reloaded.deleteFolder(chatFolder.id)
        precondition(reloaded.sidebarRoot == .agent(.chatGPT) && reloaded.selectedFolderID == nil)
        precondition(reloaded.notes.count == 3 && reloaded.folders.contains(where: { $0.id == codexFolder.id }))

        let duplicateDirectory = directory.appending(path: "duplicates", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: duplicateDirectory, withIntermediateDirectories: true)
        let duplicateURL = duplicateDirectory.appending(path: "notes.json")
        let duplicateData = try JSONEncoder().encode([replacement, replacement])
        try duplicateData.write(to: duplicateURL)
        let duplicateStore = NotesStore(fileURL: duplicateURL, foldersURL: duplicateDirectory.appending(path: "folders.json"))
        precondition(duplicateStore.libraryUnavailable)
        duplicateStore.markRead(replacement.id)
        let unchangedDuplicateData = try Data(contentsOf: duplicateURL)
        precondition(unchangedDuplicateData == duplicateData)
        print("Actual app store and MCP: read state, folder deletion, 16 parallel writes, import and duplicate detection passed")
    }

    private static func testAgentFolderVisibility() {
        let shared = Folder(name: "Build reports")
        let owned = Folder(name: "Empty project", mailbox: "Claude")
        let empty = Folder(name: "Unfiled project")
        let smart = Folder(name: "Codex", kind: .smartCodex)
        let folders = [shared, owned, empty, smart]
        let notes = [
            Note(text: "Build", sourceApp: "Codex (MCP)", folderID: shared.id),
            Note(text: "Review", sourceURL: URL(string: "https://claude.ai/chat/example"), folderID: shared.id),
            Note(text: "Cross-filed", sourceApp: "Codex", folderID: owned.id),
            Note(text: "Inbox", sourceApp: "Codex", folderID: smart.id)
        ]
        let codex = SidebarMailbox.agent(.codex)
        precondition(codex.visibleFolders(in: folders, notes: notes) == [shared])
        precondition(SidebarMailbox.agent(.claude).visibleFolders(in: folders, notes: notes) == [shared, owned])
        precondition(SidebarMailbox.agent(.grok).visibleFolders(in: folders, notes: notes).isEmpty)
        precondition(codex.visibleFolders(in: folders, notes: Array(notes.dropFirst())).isEmpty)
        precondition(SidebarMailbox.folders.visibleFolders(in: folders, notes: notes) == [shared, owned, empty])
    }

    private static func startMCP(_ binary: String, name: String, arguments: [String: Any]) throws -> Process {
        let request: [String: Any] = ["jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": ["name": name, "arguments": arguments]]
        let input = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.standardInput = input
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        try input.fileHandleForWriting.write(contentsOf: JSONSerialization.data(withJSONObject: request) + Data("\n".utf8))
        try input.fileHandleForWriting.close()
        return process
    }

    private static func callMCP(_ binary: String, name: String, arguments: [String: Any]) throws -> Process {
        let process = try startMCP(binary, name: name, arguments: arguments)
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { fatalError("MCP process failed") }
        return process
    }
}
