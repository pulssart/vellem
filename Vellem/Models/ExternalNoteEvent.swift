import Foundation

enum ExternalNoteEvent {
    static let createdName = Notification.Name("com.adriendonot.Vellem.externalNoteCreated")
    static let noteIDKey = "noteID"
    static let sourceKey = "source"

    static func postCreated(noteID: Note.ID, source: String) {
        writeLatestChange(noteID: noteID, source: source)
        DistributedNotificationCenter.default().postNotificationName(
            createdName,
            object: nil,
            userInfo: [
                noteIDKey: noteID.uuidString,
                sourceKey: source
            ],
            deliverImmediately: true
        )
    }

    static func postChanged(noteID: Note.ID? = nil, source: String) {
        writeLatestChange(noteID: noteID, source: source)
        DistributedNotificationCenter.default().postNotificationName(
            createdName,
            object: nil,
            userInfo: [
                sourceKey: source
            ],
            deliverImmediately: true
        )
    }

    static func latestCreated() -> (noteID: Note.ID, source: String?)? {
        guard let data = try? Data(contentsOf: eventURL),
              let payload = try? JSONDecoder().decode(CreatedPayload.self, from: data),
              let payloadNoteID = payload.noteID,
              let noteID = Note.ID(uuidString: payloadNoteID) else {
            return nil
        }

        return (noteID, payload.source)
    }

    private static func writeLatestChange(noteID: Note.ID?, source: String) {
        do {
            try FileManager.default.createDirectory(
                at: eventURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let payload = CreatedPayload(noteID: noteID?.uuidString, source: source, createdAt: Date())
            let data = try JSONEncoder().encode(payload)
            try data.write(to: eventURL, options: [.atomic])
        } catch {
            // The distributed notification still acts as a best-effort fallback.
        }
    }

    static var eventURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Group Containers/MKAFV9VL9V.com.adriendonot.Vellem/external-note-event.json")
    }

    private struct CreatedPayload: Codable {
        var noteID: String?
        var source: String
        var createdAt: Date
    }
}
