import Foundation

/// Applies local changes to the latest library while preserving independent writes.
enum NoteLibraryMerge {
    struct Result {
        let notes: [Note]
        let hasTextConflict: Bool
    }

    static func merge(baseline: [Note], local: [Note], disk: [Note], removingFolder: UUID? = nil) -> Result {
        let old = Dictionary(uniqueKeysWithValues: baseline.map { ($0.id, $0) })
        let current = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        var combined = Dictionary(uniqueKeysWithValues: disk.map { ($0.id, $0) })
        var hadTextConflict = false

        for id in old.keys where current[id] == nil {
            if let previous = old[id], let remote = combined[id], remote.text != previous.text {
                var copy = remote
                copy.id = UUID()
                copy.generatedTitle = "Conflict copy: \(remote.title)"
                copy.createdAt = .now
                copy.updatedAt = .now
                copy.isRead = true
                combined[copy.id] = copy
                hadTextConflict = true
            }
            combined.removeValue(forKey: id)
        }
        for note in local {
            guard let previous = old[note.id] else { combined[note.id] = note; continue }
            guard note != previous else { continue }
            guard var result = combined[note.id] else {
                // A remote deletion wins over read-state and folder changes. Keep
                // substantive local edits as a new note instead of resurrecting the deleted ID.
                if note.text != previous.text || note.generatedTitle != previous.generatedTitle || note.decisionContext != previous.decisionContext {
                    var copy = note
                    copy.id = UUID()
                    copy.generatedTitle = "Conflict copy: \(note.title)"
                    copy.createdAt = .now
                    copy.updatedAt = .now
                    copy.isRead = true
                    combined[copy.id] = copy
                    hadTextConflict = true
                }
                continue
            }
            if note.text != previous.text, result.text != previous.text, result.text != note.text {
                var copy = result
                copy.id = UUID()
                copy.generatedTitle = "Conflict copy: \(result.title)"
                copy.createdAt = .now
                copy.updatedAt = .now
                copy.isRead = true
                combined[copy.id] = copy
                hadTextConflict = true
            }
            if note.text != previous.text { result.text = note.text }
            if note.generatedTitle != previous.generatedTitle { result.generatedTitle = note.generatedTitle }
            if note.outputFormat != previous.outputFormat { result.outputFormat = note.outputFormat }
            if note.kind != previous.kind { result.kind = note.kind }
            if note.sourceApp != previous.sourceApp { result.sourceApp = note.sourceApp }
            if note.sourceURL != previous.sourceURL { result.sourceURL = note.sourceURL }
            if note.folderID != previous.folderID { result.folderID = note.folderID }
            if note.isRead != previous.isRead { result.isRead = note.isRead }
            if note.decisionContext != previous.decisionContext { result.decisionContext = note.decisionContext }
            result.updatedAt = max(result.updatedAt, note.updatedAt)
            combined[note.id] = result
        }
        if let removingFolder {
            for id in Array(combined.keys) where combined[id]?.folderID == removingFolder {
                combined[id]?.folderID = nil
            }
        }
        return Result(notes: combined.values.sorted { $0.updatedAt > $1.updatedAt }, hasTextConflict: hadTextConflict)
    }
}
