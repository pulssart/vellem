import Foundation

@main
enum LibraryFileTransactionTests {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let notesURL = root.appending(path: "notes.json")
        let foldersURL = root.appending(path: "folders.json")
        let oldNotes = Data("old notes".utf8)
        let oldFolders = Data("old folders".utf8)
        let newNotes = Data("new notes".utf8)
        let newFolders = Data("new folders".utf8)
        try oldNotes.write(to: notesURL)
        try oldFolders.write(to: foldersURL)
        try LibraryFileTransaction.replace(notesData: newNotes, foldersData: newFolders,
                                           notesURL: notesURL, foldersURL: foldersURL)
        let savedNotes = try Data(contentsOf: notesURL)
        let savedFolders = try Data(contentsOf: foldersURL)
        precondition(savedNotes == newNotes && savedFolders == newFolders)

        let invalidFolders = root.appending(path: "missing/folders.json")
        do {
            try LibraryFileTransaction.replace(notesData: oldNotes, foldersData: oldFolders,
                                               notesURL: notesURL, foldersURL: invalidFolders)
            fatalError("The second write must fail")
        } catch { }
        let notesAfterFailure = try Data(contentsOf: notesURL)
        let foldersAfterFailure = try Data(contentsOf: foldersURL)
        precondition(notesAfterFailure == newNotes && foldersAfterFailure == newFolders)
        print("Library files: successful replacement and rollback after second write failure passed")
    }
}
