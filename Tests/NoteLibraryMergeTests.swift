import Foundation

@main
enum NoteLibraryMergeTests {
    static func main() {
        let original = Note(text: "# Original\n\nBefore", isRead: false)
        precondition(original.preview == "Before")
        precondition(Note(text: "").preview == "Empty note")
        precondition(Note(text: "## Latence\n| Mesure | T4 |", generatedTitle: "Latence").preview == "Mesure · T4")
        precondition(Note(text: "def afficher(a_b):", generatedTitle: "Code", outputFormat: .code).preview == "def afficher(a_b):")
        precondition(Note(text: "{\"valeur\":42}", outputFormat: .json).title == "JSON object")
        precondition(Note(text: String(repeating: "Texte ", count: 100)).title.count <= 110)
        var edited = original
        edited.text = "# Original\n\nEdited locally"
        let incoming = Note(text: "# Incoming\n\nFrom an agent")
        let independent = NoteLibraryMerge.merge(baseline: [original], local: [edited], disk: [original, incoming])
        precondition(independent.notes.contains { $0.id == original.id && $0.text == edited.text })
        precondition(independent.notes.contains { $0.id == incoming.id })
        precondition(!independent.hasTextConflict)

        var remote = original
        remote.text = "# Original\n\nEdited by agent"
        let conflict = NoteLibraryMerge.merge(baseline: [original], local: [edited], disk: [remote])
        precondition(conflict.hasTextConflict)
        precondition(conflict.notes.count == 2)
        precondition(conflict.notes.contains { $0.id == original.id && $0.text == edited.text })
        precondition(conflict.notes.contains { $0.id != original.id && $0.text == remote.text && $0.title.hasPrefix("Conflict copy:") })

        var markedRead = original
        markedRead.isRead = true
        let differentFields = NoteLibraryMerge.merge(baseline: [original], local: [markedRead], disk: [remote])
        precondition(differentFields.notes.count == 1)
        precondition(differentFields.notes[0].isRead && differentFields.notes[0].text == remote.text)
        precondition(!differentFields.hasTextConflict)

        let remoteDeletion = NoteLibraryMerge.merge(baseline: [original], local: [markedRead], disk: [])
        precondition(remoteDeletion.notes.isEmpty)
        let editedDuringDeletion = NoteLibraryMerge.merge(baseline: [original], local: [edited], disk: [])
        precondition(editedDuringDeletion.hasTextConflict)
        precondition(editedDuringDeletion.notes.count == 1)
        precondition(editedDuringDeletion.notes[0].id != original.id && editedDuringDeletion.notes[0].text == edited.text)

        let deletion = NoteLibraryMerge.merge(baseline: [original], local: [], disk: [original, incoming])
        precondition(deletion.notes.map(\.id) == [incoming.id])
        let deletionWithRemoteEdit = NoteLibraryMerge.merge(baseline: [original], local: [], disk: [remote])
        precondition(deletionWithRemoteEdit.hasTextConflict)
        precondition(deletionWithRemoteEdit.notes.count == 1)
        precondition(deletionWithRemoteEdit.notes[0].id != original.id && deletionWithRemoteEdit.notes[0].text == remote.text)

        let folderID = UUID()
        var incomingInDeletedFolder = incoming
        incomingInDeletedFolder.folderID = folderID
        let folderDeletion = NoteLibraryMerge.merge(baseline: [original], local: [original],
                                                   disk: [original, incomingInDeletedFolder], removingFolder: folderID)
        precondition(folderDeletion.notes.contains { $0.id == incoming.id && $0.folderID == nil })
        print("Note library merge: independent writes, text conflict, separate fields, note and folder deletion passed")
    }
}
