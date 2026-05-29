import Foundation
import UserNotifications

enum MobileFolderNotificationScanner {
    private static let assignmentsKey = "mobileFolderNotificationAssignments"

    static func scan(notes: [Note], folders: [Folder], shouldNotify: Bool) {
        let defaults = UserDefaults.standard
        let previous = defaults.dictionary(forKey: assignmentsKey) as? [String: String]
        let hasBaseline = previous != nil
        var next: [String: String] = [:]
        let folderNames = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0.name) })

        for note in notes {
            let noteKey = note.id.uuidString
            let folderKey = note.folderID?.uuidString ?? ""
            next[noteKey] = folderKey

            guard shouldNotify,
                  hasBaseline,
                  let folderID = note.folderID,
                  previous?[noteKey] != folderKey else {
                continue
            }

            notify(note: note, folderName: folderNames[folderID] ?? "Folder")
        }

        defaults.set(next, forKey: assignmentsKey)
    }

    static func refreshAndNotify() async {
        do {
            async let notesTask = Task.detached(priority: .utility) {
                try CloudMirrorStore.loadNotes([Note].self)
            }.value
            async let foldersTask = Task.detached(priority: .utility) {
                try CloudMirrorStore.loadFolders([Folder].self)
            }.value

            let notes = try await notesTask.sorted { $0.updatedAt > $1.updatedAt }
            let folders = try await foldersTask.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            scan(notes: notes, folders: folders, shouldNotify: true)
        } catch {
            return
        }
    }

    private static func notify(note: Note, folderName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Nouvelle note dans \(folderName)"
        content.body = note.title
        content.sound = .default
        content.userInfo = ["noteID": note.id.uuidString]

        let request = UNNotificationRequest(
            identifier: "vellem-mobile-note-\(note.id.uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
