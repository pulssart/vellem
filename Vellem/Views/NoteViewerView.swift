import AppKit
import SwiftUI

struct NoteViewerView: View {
    @ObservedObject var store: NotesStore
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var copyToken: UUID?

    var body: some View {
        Group {
            if let note = store.viewerNote {
                content(for: note)
            } else {
                MessageSelectionPlaceholder()
            }
        }
        .frame(minWidth: 320, idealWidth: 560, maxWidth: .infinity, minHeight: 240, idealHeight: 600, maxHeight: .infinity)
        .background(InboxPalette.paper)
        .background(NoteViewerWindowConfigurator())
        .preferredColorScheme(.light)
        .onExitCommand { dismissWindow(id: "note-viewer") }
    }

    private func content(for note: Note) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(for: note)
            MarkdownRenderedView(note: note)

            footer(for: note)
            if let conversation = note.conversation { ReplyComposer(note: note, conversation: conversation) }
        }
        .ignoresSafeArea(.container, edges: .top)
        .navigationTitle(note.title)
        .onAppear {
            store.markRead(note.id)
        }
        .onChange(of: note.id) { _, _ in
            copyToken = nil
        }
        .task(id: copyToken) {
            guard copyToken != nil else { return }
            do { try await Task.sleep(for: .seconds(1.5)) } catch { return }
            copyToken = nil
        }
    }

    private func header(for note: Note) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .help(note.title)
                HStack(spacing: 6) {
                    Text(note.updatedAt, style: .relative)
                    Text("·")
                    Text("\(note.wordCount) words")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
            }
            Spacer(minLength: 0)
            Button {
                copyNoteReference(note)
            } label: {
                MessageCopyLabel(token: copyToken, action: "Copy note reference", confirmation: "Note reference copied.")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .help("Copy note reference")
        }
        .padding(.leading, 86) // Leave the native window controls unobstructed.
        .padding(.trailing, 12)
        .padding(.vertical, 7)
        .frame(minHeight: 52)
        .background {
            InboxPalette.frame
                .gesture(WindowDragGesture())
        }
        .environment(\.colorScheme, .dark)
    }

    private func footer(for note: Note) -> some View {
        HStack {
            Spacer()
            if let sourceDescription = sourceDescription(for: note) {
                Label(sourceDescription, systemImage: note.sourceURL == nil ? "app" : "link")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .help(sourceDescription)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func sourceDescription(for note: Note) -> String? {
        switch (note.sourceApp, note.sourceURL) {
        case let (sourceApp?, sourceURL?):
            "\(sourceApp), \(sourceURL.absoluteString)"
        case let (sourceApp?, nil):
            sourceApp
        case let (nil, sourceURL?):
            sourceURL.absoluteString
        case (nil, nil):
            nil
        }
    }

    private func copyNoteReference(_ note: Note) {
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(store.noteReference(for: note), forType: .string) else { return }
        copyToken = UUID()
    }

}

private struct NoteViewerWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(window: view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(window: nsView.window) }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.hidesOnDeactivate = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        window.hasShadow = true
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.insert(.resizable)
        window.titlebarSeparatorStyle = .none
        window.minSize = NSSize(width: 320, height: 240)
        alignToPixelGrid(window)
        window.orderFrontRegardless()
    }

    private func alignToPixelGrid(_ window: NSWindow) {
        let scale = window.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        var frame = window.frame
        frame.origin.x = (frame.origin.x * scale).rounded() / scale
        frame.origin.y = (frame.origin.y * scale).rounded() / scale
        frame.size.width = (frame.size.width * scale).rounded() / scale
        frame.size.height = (frame.size.height * scale).rounded() / scale

        if frame != window.frame {
            window.setFrame(frame, display: false)
        }
    }
}
