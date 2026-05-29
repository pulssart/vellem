import Foundation

enum CloudMirrorStore {
    static let containerIdentifier = "iCloud.com.adriendonot.Vellem"

    private static let folderName = "Vellem"
    private static let notesFileName = "notes.json"
    private static let foldersFileName = "folders.json"

    static var containerURL: URL? {
        if let ubiquityURL = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) {
            return ubiquityURL
                .appending(path: "Documents", directoryHint: .isDirectory)
                .appending(path: folderName, directoryHint: .isDirectory)
        }

        #if os(macOS)
        let localContainerName = containerIdentifier.replacingOccurrences(of: ".", with: "~")
        return FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library", directoryHint: .isDirectory)
            .appending(path: "Mobile Documents", directoryHint: .isDirectory)
            .appending(path: localContainerName, directoryHint: .isDirectory)
            .appending(path: "Documents", directoryHint: .isDirectory)
            .appending(path: folderName, directoryHint: .isDirectory)
        #else
        return nil
        #endif
    }

    static var notesURL: URL? {
        containerURL?.appending(path: notesFileName)
    }

    static var foldersURL: URL? {
        containerURL?.appending(path: foldersFileName)
    }

    static func publish(notesData: Data, foldersData: Data? = nil) throws {
        guard let containerURL else { return }
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        try write(notesData, to: containerURL.appending(path: notesFileName))

        if let foldersData {
            try write(foldersData, to: containerURL.appending(path: foldersFileName))
        }
    }

    static func publish(foldersData: Data) throws {
        guard let foldersURL else { return }
        try FileManager.default.createDirectory(at: foldersURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try write(foldersData, to: foldersURL)
    }

    static func loadNotes<T: Decodable>(_ type: T.Type, decoder: JSONDecoder = JSONDecoder()) throws -> T {
        guard let notesURL else {
            throw CloudMirrorError.unavailable
        }
        try startDownloadingIfNeeded(notesURL)
        let data = try coordinatedRead(from: notesURL)
        return try decoder.decode(type, from: data)
    }

    static func loadFolders<T: Decodable>(_ type: T.Type, decoder: JSONDecoder = JSONDecoder()) throws -> T {
        guard let foldersURL else {
            throw CloudMirrorError.unavailable
        }
        try startDownloadingIfNeeded(foldersURL)
        let data = try coordinatedRead(from: foldersURL)
        return try decoder.decode(type, from: data)
    }

    private static func write(_ data: Data, to url: URL) throws {
        var coordinationError: NSError?
        var writeError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { coordinatedURL in
            do {
                try data.write(to: coordinatedURL, options: [.atomic])
            } catch {
                writeError = error
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        if let writeError {
            throw writeError
        }
    }

    private static func coordinatedRead(from url: URL) throws -> Data {
        var coordinationError: NSError?
        var readResult: Result<Data, Error>?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            readResult = Result {
                try Data(contentsOf: coordinatedURL)
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        return try readResult?.get() ?? Data()
    }

    private static func startDownloadingIfNeeded(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let values = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        if values.ubiquitousItemDownloadingStatus == .notDownloaded {
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
    }
}

enum CloudMirrorError: Error {
    case unavailable
}
