import AppKit
import SwiftUI

struct NoteContextMenu: View {
    let note: Note
    let openInFloatingViewer: (Note) -> Void
    let createFolderForNote: ((Note) -> Void)?
    @ObservedObject private var store: NotesStore

    init(
        note: Note,
        store: NotesStore,
        openInFloatingViewer: @escaping (Note) -> Void,
        createFolderForNote: ((Note) -> Void)? = nil
    ) {
        self.note = note
        self.openInFloatingViewer = openInFloatingViewer
        self.createFolderForNote = createFolderForNote
        _store = ObservedObject(wrappedValue: store)
    }

    var body: some View {
        Button("Open in floating window") {
            openInFloatingViewer(note)
        }

        Menu("Move to") {
            Button("No folder") {
                store.moveNote(note.id, toFolder: nil)
            }

            if !store.folders.isEmpty {
                Divider()
                ForEach(store.folders) { folder in
                    Button(folder.name) {
                        store.moveNote(note.id, toFolder: folder.id)
                    }
                }
            }

            if let createFolderForNote {
                Divider()
                Button("New folder…") {
                    createFolderForNote(note)
                }
            }
        }

        Button("Copy") {
            copy(note.text)
        }

        Button(note.isRead ? "Mark as unread" : "Mark as read") {
            note.isRead ? store.markUnread(note.id) : store.markRead(note.id)
        }

        Button("Delete", role: .destructive) {
            store.delete(note)
        }
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
