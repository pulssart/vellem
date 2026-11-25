import SwiftUI

struct NoteReaderView: View {
    @ObservedObject var store: NotesStore
    let note: Note
    @State private var textSizeStep = 0
    @State private var copyToken: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    NSPasteboard.general.clearContents()
                    guard NSPasteboard.general.setString(note.text, forType: .string) else { return }
                    copyToken = UUID()
                } label: {
                    MessageCopyLabel(token: copyToken)
                        .padding(.horizontal, 5)
                        .foregroundStyle(copyToken == nil ? Color.secondary : InboxPalette.ink)
                        .inboxActionGroup()
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .task(id: copyToken) {
                    guard copyToken != nil else { return }
                    try? await Task.sleep(for: .seconds(1.5))
                    if !Task.isCancelled { copyToken = nil }
                }
                Spacer()
                Menu {
                    Text("\(note.wordCount) words")
                    Section("Text size") {
                        Button("Increase") { textSizeStep += 1 }.disabled(textSizeStep >= 8)
                        Button("Decrease") { textSizeStep -= 1 }.disabled(textSizeStep <= 0)
                        Button("Reset") { textSizeStep = 0 }.disabled(textSizeStep == 0)
                    }
                    Divider()
                    Button("Delete note", role: .destructive) { store.delete(note) }
                } label: {
                    Image(systemName: "ellipsis").frame(width: 24, height: 22)
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .accessibilityLabel("More").help("More").inboxActionGroup()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12).frame(height: 49)
            .background { InboxPalette.header }
            .background { Color.clear.contentShape(Rectangle()).gesture(WindowDragGesture()) }
            Divider()
            MarkdownRenderedView(note: note, textSizeStep: textSizeStep,
                                 showsEnvelope: true, agent: store.agent(for: note),
                                 folderName: store.folders.first { $0.id == note.folderID }?.name)
            if let conversation = note.conversation { ReplyComposer(note: note, conversation: conversation) }
        }
        .navigationTitle(note.title)
        .onAppear { store.markRead(note.id) }
        .onChange(of: note.id) { _, id in
            copyToken = nil
            textSizeStep = 0
            store.markRead(id)
        }
    }
}
