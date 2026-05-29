import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct NoteEditorView: View {
    @ObservedObject var store: NotesStore
    let note: Note

    @State private var text: String = ""
    @State private var isEditing = false
    @State private var isDroppingImage = false
    @State private var isApplyingStoreUpdate = false
    @State private var previewTextSizeStep = 0
    @State private var isPreviewMode = true
    @State private var scrambleFrame: ScrambleFrame?
    @State private var message: String?
    @State private var saveTask: Task<Void, Never>?
    @StateObject private var richController = RichMarkdownController()
    @AppAccent private var accent

    private let editor = FoundationNoteEditor()
    private let noteHorizontalPadding: CGFloat = 36

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(nsColor: .windowBackgroundColor))

            ZStack {
                if isPreviewMode {
                    MarkdownRenderedView(
                        text: $text,
                        textSizeStep: previewTextSizeStep,
                        contentPadding: EdgeInsets(top: 8, leading: 12, bottom: 18, trailing: 12)
                    )
                    .onChange(of: text) { _, newValue in
                        guard !isApplyingStoreUpdate else { return }
                        scheduleSave(newValue)
                    }
                } else {
                    RichMarkdownTextView(
                        text: $text,
                        textSizeStep: previewTextSizeStep,
                        controller: richController,
                        onScheduleSave: { newValue in
                            guard !isApplyingStoreUpdate else { return }
                            scheduleSave(newValue)
                        },
                        onRunAction: { action in
                            run(action)
                        }
                    )
                }

                if let scrambleFrame {
                    ScramblePreviewView(frame: scrambleFrame, textSizeStep: previewTextSizeStep)
                }
            }
                .padding(.horizontal, noteHorizontalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .overlay {
            if isDroppingImage {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(accent.color, lineWidth: 3)
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(
            of: [UTType.fileURL.identifier, UTType.image.identifier],
            isTargeted: $isDroppingImage,
            perform: handleDrop(providers:)
        )
        .navigationTitle(note.title)
        .onAppear {
            text = note.text
            store.markRead(note.id)
        }
        .onChange(of: note.id) {
            saveTask?.cancel()
            isApplyingStoreUpdate = true
            text = note.text
            isPreviewMode = true
            scrambleFrame = nil
            message = nil
            DispatchQueue.main.async {
                isApplyingStoreUpdate = false
            }
        }
        .onChange(of: note.text) {
            guard text != note.text else { return }
            isApplyingStoreUpdate = true
            text = note.text
            scrambleFrame = nil
            DispatchQueue.main.async {
                isApplyingStoreUpdate = false
            }
        }
        .onDisappear {
            saveTask?.cancel()
            flushSave()
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 4) {
            if !isPreviewMode {
                formattingToolbar
            }

            if let sourceBadgeInfo {
                sourceBadge(sourceBadgeInfo)
                    .padding(.leading, !isPreviewMode ? 6 : 0)
            }

            Spacer()

            Button {
                isPreviewMode.toggle()
            } label: {
                Label(isPreviewMode ? "Edit" : "Preview", systemImage: isPreviewMode ? "pencil" : "eye")
                    .labelStyle(.titleAndIcon)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .contentShape(Rectangle())
            }
            .help(isPreviewMode ? "Edit mode (⌘⇧P)" : "Preview mode (⌘⇧P)")
            .keyboardShortcut("p", modifiers: [.command, .shift])

            toolbarDivider

            Text(statusText)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.trailing, 4)

            // AI menu (Edit + Translate combined)
            Menu {
                Section("Format") {
                    Button {
                        run(.format)
                    } label: {
                        Label(EditAction.format.label, systemImage: EditAction.format.systemImage)
                    }
                }
                Section("Edit") {
                    ForEach(EditAction.manualActions) { action in
                        Button {
                            run(action)
                        } label: {
                            Label(action.label, systemImage: action.systemImage)
                        }
                    }
                }
                Section("Translate to") {
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
                    .frame(width: 24, height: 22)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(isEditing || cleanedText.isEmpty)
            .help("Apple Intelligence")
            .tint(accent.color)

            // Overflow
            Menu {
                Section("Text size") {
                    Button("Increase") { previewTextSizeStep = min(8, previewTextSizeStep + 1) }
                        .disabled(previewTextSizeStep == 8)
                    Button("Decrease") { previewTextSizeStep = max(0, previewTextSizeStep - 1) }
                        .disabled(previewTextSizeStep == 0)
                    Button("Reset") { previewTextSizeStep = 0 }
                        .disabled(previewTextSizeStep == 0)
                }
                Divider()
                Button(role: .destructive) {
                    store.delete(note)
                } label: {
                    Label("Delete note", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 24, height: 22)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More")
        }
        .buttonStyle(.borderless)
        .labelStyle(.iconOnly)
        .foregroundStyle(.secondary)
        .tint(.secondary)
    }

    private func sourceBadge(_ info: SourceBadgeInfo) -> some View {
        HStack(spacing: 7) {
            if let assetName = info.assetName {
                Image(assetName)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: info.systemImage)
                    .font(.system(size: 12, weight: .semibold))
            }

            Text("From")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.78))

            Text(info.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(accent.color.opacity(0.14))
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(accent.color.opacity(0.34), lineWidth: 1)
        }
        .foregroundStyle(accent.color.mix(with: .black, by: 0.16))
        .frame(maxWidth: 220, alignment: .leading)
        .accessibilityLabel("From \(info.label)")
    }

    @ViewBuilder
    private var formattingToolbar: some View {
        toolbarIcon("bold", help: "Bold (⌘B)") { richController.toggleBold() }
            .keyboardShortcut("b", modifiers: [.command])
        toolbarIcon("italic", help: "Italic (⌘I)") { richController.toggleItalic() }
            .keyboardShortcut("i", modifiers: [.command])
        toolbarIcon("underline", help: "Underline (⌘U)") { richController.toggleUnderline() }
            .keyboardShortcut("u", modifiers: [.command])
        toolbarIcon("strikethrough", help: "Strikethrough") { richController.toggleStrikethrough() }

        toolbarDivider

        Menu {
            Button("Title") { richController.setHeading(1) }
                .keyboardShortcut("1", modifiers: [.command])
            Button("Subtitle") { richController.setHeading(2) }
                .keyboardShortcut("2", modifiers: [.command])
            Button("Heading") { richController.setHeading(3) }
                .keyboardShortcut("3", modifiers: [.command])
            Divider()
            Button("Plain text") { richController.clearLinePrefix() }
                .keyboardShortcut("0", modifiers: [.command])
        } label: {
            Image(systemName: "textformat.size")
                .frame(width: 24, height: 22)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Heading (⌘1 / ⌘2 / ⌘3)")

        toolbarIcon("checklist", help: "Todo (⌘L)") { richController.toggleTodo() }
            .keyboardShortcut("l", modifiers: [.command])
    }

    private func toolbarIcon(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
        }
        .help(help)
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.6))
            .frame(width: 1, height: 16)
            .padding(.horizontal, 4)
    }

    private var statusText: String {
        if currentWordCount == 1 {
            return "1 word"
        }

        return "\(currentWordCount) words"
    }

    private var cleanedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sourceBadgeInfo: SourceBadgeInfo? {
        if note.isFromCodex {
            return SourceBadgeInfo(label: "Codex", assetName: "CodexSourceIcon")
        }

        if note.isFromClaude {
            return SourceBadgeInfo(label: "Claude", assetName: "ClaudeSourceIcon")
        }

        guard let sourceDescription else { return nil }
        return SourceBadgeInfo(
            label: sourceDescription,
            systemImage: note.sourceURL == nil ? "app.badge" : "link"
        )
    }

    private var sourceDescription: String? {
        switch (note.sourceApp, note.sourceURL) {
        case let (appName?, url?):
            "\(appName), \(url.absoluteString)"
        case let (appName?, nil):
            appName
        case let (nil, url?):
            url.absoluteString
        case (nil, nil):
            nil
        }
    }

    private var currentWordCount: Int {
        text
            .split { $0.isWhitespace || $0.isNewline }
            .count
    }

    private func run(_ action: EditAction) {
        guard !cleanedText.isEmpty else {
            message = NoteEditError.empty.localizedDescription
            return
        }

        flushSave()
        isEditing = true
        message = action == .format ? "Formatting with Apple Foundation Models..." : "Editing with Apple Foundation Models..."

        Task {
            do {
                let result = try await editor.edit(text, action: action)
                await MainActor.run {
                    if action == .title {
                        store.updateTitle(result, for: note.id)
                    }
                }
                if action != .title {
                    await animateScrambledText(to: result)
                    await MainActor.run {
                        store.update(noteID: note.id, text: result)
                    }
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

        flushSave()
        isEditing = true
        message = "Translating with Apple Foundation Models..."

        Task {
            do {
                let result = try await editor.translate(text, to: language)
                await animateScrambledText(to: result)
                await MainActor.run {
                    store.update(noteID: note.id, text: result)
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
        isApplyingStoreUpdate = true
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
        isApplyingStoreUpdate = false
    }

    private func scheduleSave(_ newValue: String) {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                store.update(noteID: note.id, text: newValue)
            }
        }
    }

    private func flushSave() {
        saveTask?.cancel()
        guard text != note.text else { return }
        store.update(noteID: note.id, text: text)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let url = NoteAttachmentStore.droppedFileURL(from: item) else { return }
                    DispatchQueue.main.async {
                        insertDroppedImage(from: url)
                    }
                }
                return true
            }

            if provider.canLoadObject(ofClass: NSImage.self) {
                _ = provider.loadObject(ofClass: NSImage.self) { image, _ in
                    guard let image = image as? NSImage else { return }
                    DispatchQueue.main.async {
                        insertDroppedImage(image)
                    }
                }
                return true
            }
        }

        return false
    }

    @MainActor
    private func insertDroppedImage(from sourceURL: URL) {
        do {
            let attachmentURL = try NoteAttachmentStore.copyImage(from: sourceURL)
            insertImageMarkdown(for: attachmentURL, alt: sourceURL.deletingPathExtension().lastPathComponent)
        } catch {
            message = "Image could not be added."
        }
    }

    @MainActor
    private func insertDroppedImage(_ image: NSImage) {
        do {
            let attachmentURL = try NoteAttachmentStore.saveImage(image)
            insertImageMarkdown(for: attachmentURL, alt: "Image")
        } catch {
            message = "Image could not be added."
        }
    }

    private func insertImageMarkdown(for url: URL, alt: String) {
        saveTask?.cancel()

        let safeAlt = alt.isEmpty ? "Image" : alt.replacingOccurrences(of: "]", with: "")
        let insertion = "![\(safeAlt)](\(url.absoluteString))"
        let separator = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\n\n"
        let updatedText = text + separator + insertion

        text = updatedText
        message = "Image added."
        store.update(noteID: note.id, text: updatedText)
    }
}

private struct SourceBadgeInfo {
    var label: String
    var assetName: String?
    var systemImage: String

    init(label: String, assetName: String? = nil, systemImage: String = "app.badge") {
        self.label = label
        self.assetName = assetName
        self.systemImage = systemImage
    }
}

struct ScramblePreviewView: View {
    let frame: ScrambleFrame
    let textSizeStep: Int
    @AppAccent private var accent

    var body: some View {
        ScrollView {
            Text(attributedText)
                .font(.system(size: textSize))
                .lineSpacing(lineSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .textSelection(.disabled)
        .transition(.opacity)
    }

    private var attributedText: AttributedString {
        var value = AttributedString(frame.text)

        for offset in frame.yellowOffsets {
            let start = value.index(value.startIndex, offsetByCharacters: offset)
            let end = value.index(start, offsetByCharacters: 1)
            value[start..<end].foregroundColor = accent.color
        }

        return value
    }

    private var textSize: CGFloat {
        16 + CGFloat(textSizeStep) * 2
    }

    private var lineSpacing: CGFloat {
        5 + CGFloat(textSizeStep) * 0.9
    }
}

struct MarkdownImage: Hashable {
    let alt: String
    let url: URL

    static func parse(_ line: String) -> MarkdownImage? {
        guard line.hasPrefix("!["),
              let closeAlt = line.firstIndex(of: "]"),
              line[line.index(after: closeAlt)...].hasPrefix("("),
              line.hasSuffix(")") else {
            return nil
        }

        let alt = String(line[line.index(line.startIndex, offsetBy: 2)..<closeAlt])
        let urlStart = line.index(closeAlt, offsetBy: 2)
        let urlEnd = line.index(before: line.endIndex)
        guard urlStart < urlEnd,
              let url = URL(string: String(line[urlStart..<urlEnd])) else {
            return nil
        }

        return MarkdownImage(alt: alt, url: url)
    }
}

struct NoteImageView: View {
    let image: MarkdownImage

    var body: some View {
        if let nsImage = NSImage(contentsOf: image.url) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(image.alt)
        } else {
            Label("Image unavailable", systemImage: "photo")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

enum NoteAttachmentStore {
    static func copyImage(from sourceURL: URL) throws -> URL {
        guard isSupportedImage(sourceURL) else { throw AttachmentError.unsupportedType }

        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try FileManager.default.createDirectory(
            at: AppGroup.attachmentsURL,
            withIntermediateDirectories: true
        )

        let destination = uniqueAttachmentURL(pathExtension: sourceURL.pathExtension)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }

    static func saveImage(_ image: NSImage) throws -> URL {
        guard let data = pngData(for: image) else { throw AttachmentError.invalidImage }

        try FileManager.default.createDirectory(
            at: AppGroup.attachmentsURL,
            withIntermediateDirectories: true
        )

        let destination = uniqueAttachmentURL(pathExtension: "png")
        try data.write(to: destination, options: [.atomic])
        return destination
    }

    private static func uniqueAttachmentURL(pathExtension: String) -> URL {
        let cleanedExtension = pathExtension.isEmpty ? "png" : pathExtension.lowercased()
        return AppGroup.attachmentsURL
            .appending(path: "\(UUID().uuidString).\(cleanedExtension)")
    }

    static func droppedFileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }

        if let data = item as? Data,
           let string = String(data: data, encoding: .utf8) {
            return URL(string: string)
        }

        if let string = item as? String {
            return URL(string: string)
        }

        return nil
    }

    private static func isSupportedImage(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }

    private static func pngData(for image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }

    enum AttachmentError: Error {
        case unsupportedType
        case invalidImage
    }
}
