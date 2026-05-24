import SwiftUI

struct EmptyNotesView: View {
    @ObservedObject var store: NotesStore

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "note.text.badge.plus")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text("No notes yet")
                .font(.title3)
                .fontWeight(.semibold)

            Button {
                store.createDraft()
            } label: {
                Label("Create Note", systemImage: "square.and.pencil")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
