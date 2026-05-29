import SwiftUI

struct MenuBarComposerView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    @ObservedObject var store: NotesStore
    @Binding var text: String

    @State private var editingNoteID: Note.ID?
    @State private var isEditing = false
    @State private var scrambleFrame: ScrambleFrame?
    @State private var message: String?

    private let editor = FoundationNoteEditor()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quick note")
                    .font(.headline)
                Spacer()
                Button {
                    openMainWindow()
                } label: {
                    Image(systemName: "macwindow")
                }
                .buttonStyle(.borderless)
                .help("Open window")

                Button {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Settings")

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.borderless)
                .help("Quit")
            }

            ZStack {
                TextEditor(text: $text)
                    .font(.body)
                    .frame(height: 150)
                    .overlay {
                        if text.isEmpty {
                            Text("Drop the thought here.")
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }

                if let scrambleFrame {
                    ScramblePreviewView(frame: scrambleFrame, textSizeStep: 0)
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: 8) {
                Button {
                    newCapture()
                } label: {
                    Image(systemName: "plus")
                }
                .help("New note")

                Button {
                    saveToToday()
                } label: {
                    Image(systemName: "calendar")
                }
                .help("Add to today")
                .disabled(cleanedText.isEmpty)

                Button {
                    save()
                } label: {
                    Image(systemName: "return")
                }
                .help("Save")
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(cleanedText.isEmpty)

                Menu {
                    Button {
                        run(.format)
                    } label: {
                        Label(EditAction.format.label, systemImage: EditAction.format.systemImage)
                    }

                    Divider()

                    ForEach(EditAction.manualActions) { action in
                        Button {
                            run(action)
                        } label: {
                            Label(action.label, systemImage: action.systemImage)
                        }
                    }

                    Divider()

                    Menu("Translate") {
                        ForEach(TranslationLanguage.allCases) { language in
                            Button {
                                translate(to: language)
                            } label: {
                                Label(language.label, systemImage: language.systemImage)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "sparkles")
                }
                .help("Edit")
                .disabled(isEditing || cleanedText.isEmpty)

                Button {
                    copy(text)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help("Copy")
                .disabled(cleanedText.isEmpty)

                Spacer()
            }
            .labelStyle(.iconOnly)

            if isEditing {
                ProgressView()
                    .controlSize(.small)
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Recent")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(store.notes.prefix(5)) { note in
                    HStack(spacing: 8) {
                        Button {
                            load(note)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.title)
                                    .font(.callout)
                                    .lineLimit(1)
                                Text(note.preview)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        Button {
                            openInFloatingViewer(note)
                        } label: {
                            Image(systemName: "rectangle.on.rectangle")
                        }
                        .buttonStyle(.borderless)
                        .help("Open in floating window")

                        Button {
                            copy(note.text)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy note")
                    }
                }
            }
        }
        .padding(14)
    }

    private var cleanedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        if let editingNoteID,
           let note = store.notes.first(where: { $0.id == editingNoteID }) {
            store.update(note, text: text, regenerateTitle: true)
            message = "Saved."
            return
        }

        guard let note = store.createQuickCapture(text: text) else { return }
        editingNoteID = note.id
        text = ""
        editingNoteID = nil
        message = "Saved."
    }

    private func saveToToday() {
        store.upsertDailyNote(appending: text)
        editingNoteID = nil
        text = ""
        message = "Added to today."
    }

    private func newCapture() {
        editingNoteID = nil
        text = ""
        scrambleFrame = nil
        message = nil
    }

    private func load(_ note: Note) {
        editingNoteID = note.id
        text = note.text
        scrambleFrame = nil
        store.selectedNoteID = note.id
        store.markRead(note.id)
        message = nil
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        message = "Copied."
    }

    private func run(_ action: EditAction) {
        guard !cleanedText.isEmpty else {
            message = NoteEditError.empty.localizedDescription
            return
        }

        isEditing = true
        message = "Editing..."

        Task {
            do {
                let result = try await editor.edit(text, action: action)
                if action == .title {
                    await MainActor.run {
                        if let editingNoteID {
                            store.updateTitle(result, for: editingNoteID)
                        } else {
                            text = result
                        }
                    }
                } else {
                    await animateScrambledText(to: result)
                }
                await MainActor.run {
                    message = nil
                    isEditing = false
                }
            } catch {
                await MainActor.run {
                    message = error.localizedDescription
                    isEditing = false
                }
            }
        }
    }

    private func translate(to language: TranslationLanguage) {
        guard !cleanedText.isEmpty else {
            message = NoteEditError.empty.localizedDescription
            return
        }

        isEditing = true
        message = "Translating..."

        Task {
            do {
                let result = try await editor.translate(text, to: language)
                await animateScrambledText(to: result)
                await MainActor.run {
                    message = nil
                    isEditing = false
                }
            } catch {
                await MainActor.run {
                    message = error.localizedDescription
                    isEditing = false
                }
            }
        }
    }

    @MainActor
    private func animateScrambledText(to result: String) async {
        let frames = 18

        for frame in 0..<frames {
            scrambleFrame = ScrambleTextEffect.frame(
                for: result,
                progress: Double(frame) / Double(frames)
            )
            try? await Task.sleep(for: .milliseconds(80))
        }

        text = result
        scrambleFrame = nil
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openInFloatingViewer(_ note: Note) {
        store.viewerNoteID = note.id
        openWindow(id: "note-viewer")
        NSApp.activate(ignoringOtherApps: true)
    }
}
