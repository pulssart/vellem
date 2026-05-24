import Foundation

enum AppGroup {
    static let identifier = "MKAFV9VL9V.com.adriendonot.Vellem"
    static let legacyIdentifier = "group.com.adriendonot.Vellem"

    static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return url
        }

        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vellem", directoryHint: .isDirectory)
    }

    static var notesURL: URL {
        containerURL.appending(path: "notes.json")
    }

    static var foldersURL: URL {
        containerURL.appending(path: "folders.json")
    }

    static var attachmentsURL: URL {
        containerURL.appending(path: "Attachments", directoryHint: .isDirectory)
    }

    static var applicationSupportNotesURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/Vellem/notes.json")
    }

    static var legacyNotesURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Group Containers/\(legacyIdentifier)/notes.json")
    }

    static var macGroupNotesURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Group Containers/\(identifier)/notes.json")
    }
}
