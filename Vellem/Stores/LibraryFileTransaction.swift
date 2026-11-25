import Foundation

/// Replaces the two library files while the caller holds the library write lock.
enum LibraryFileTransaction {
    static func replace(notesData: Data, foldersData: Data, notesURL: URL, foldersURL: URL) throws {
        let fileManager = FileManager.default
        let oldNotes = fileManager.fileExists(atPath: notesURL.path) ? try Data(contentsOf: notesURL) : nil
        let oldFolders = fileManager.fileExists(atPath: foldersURL.path) ? try Data(contentsOf: foldersURL) : nil
        do {
            try notesData.write(to: notesURL, options: [.atomic])
            try foldersData.write(to: foldersURL, options: [.atomic])
        } catch {
            let originalError = error
            var recoveryErrors: [String] = []
            do { try restore(oldNotes, at: notesURL) }
            catch { recoveryErrors.append(error.localizedDescription) }
            do { try restore(oldFolders, at: foldersURL) }
            catch { recoveryErrors.append(error.localizedDescription) }
            if !recoveryErrors.isEmpty {
                throw NSError(domain: "VellemLibrary", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "The change failed and the previous library could not be fully restored: \(recoveryErrors.joined(separator: "; "))"
                ])
            }
            throw originalError
        }
    }

    private static func restore(_ data: Data?, at url: URL) throws {
        if let data {
            try data.write(to: url, options: [.atomic])
        } else if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
