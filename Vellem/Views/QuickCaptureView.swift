import SwiftUI

struct QuickCaptureView: View {
    @ObservedObject var store: NotesStore
    @Environment(\.dismissWindow) private var dismissWindow

    @AppStorage("quickCaptureAppendsToDailyNoteByChoice") private var appendsToDailyNote = false
    @AppStorage("quickCaptureFloatsAboveOtherWindows") private var floatsAboveOtherWindows = true

    @State private var text = ""
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            TextEditor(text: $text)
                .font(.body)
                .foregroundStyle(inkColor)
                .tint(inkColor)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 150)
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .background(surfaceColor)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Write before it slips.")
                            .foregroundStyle(placeholderColor)
                            .padding(.top, 14)
                            .padding(.leading, 19)
                            .allowsHitTesting(false)
                    }
                }

            footer
        }
        .frame(minWidth: 360, idealWidth: 420, maxWidth: .infinity, minHeight: 240, idealHeight: 300, maxHeight: .infinity)
        .foregroundStyle(inkColor)
        .tint(inkColor)
        .background(surfaceColor)
        .background(QuickCaptureWindowConfigurator(floatsAboveOtherWindows: floatsAboveOtherWindows))
    }

    private var surfaceColor: Color {
        Color(red: 1.0, green: 0.94, blue: 0.70)
    }

    private var inkColor: Color {
        Color(red: 0.22, green: 0.16, blue: 0.04)
    }

    private var secondaryInkColor: Color {
        inkColor.opacity(0.68)
    }

    private var placeholderColor: Color {
        inkColor.opacity(0.38)
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Quick capture")
                    .font(.headline)
                    .foregroundStyle(inkColor)

                Text(appendsToDailyNote ? "Adds to today's note" : "Creates a new note")
                    .font(.caption)
                    .foregroundStyle(secondaryInkColor)
            }

            Spacer()

            Toggle(isOn: $appendsToDailyNote) {
                Image(systemName: "calendar")
            }
            .toggleStyle(.button)
            .help("Append to today's note")

            Toggle(isOn: $floatsAboveOtherWindows) {
                Image(systemName: "pin")
            }
            .toggleStyle(.button)
            .help("Keep above other windows")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(surfaceColor)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    save()
                } label: {
                    Label("Save", systemImage: "return")
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(cleanedText.isEmpty)

                Spacer()

                Button {
                    clear()
                } label: {
                    Image(systemName: "xmark")
                }
                .help("Clear")
                .disabled(text.isEmpty)
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(secondaryInkColor)
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(surfaceColor)
    }

    private var cleanedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !cleanedText.isEmpty else { return }

        if appendsToDailyNote {
            store.upsertDailyNote(appending: cleanedText)
        } else {
            store.create(text: cleanedText)
        }

        clear()
        message = appendsToDailyNote ? "Added to today." : "Saved."
        dismissWindow(id: "quick-capture")
    }

    private func clear() {
        text = ""
    }
}
