import AppKit
import SwiftUI

// MARK: - Custom Attachment

final class MarkdownAttachment: NSTextAttachment {
    enum Kind {
        case todo(checked: Bool)
        case bullet
        case image
    }

    var kind: Kind
    /// The original markdown substring this attachment replaces (for round-tripping back to plain text).
    var sourceMarkdown: String

    init(kind: Kind, sourceMarkdown: String, image: NSImage? = nil) {
        self.kind = kind
        self.sourceMarkdown = sourceMarkdown
        super.init(data: nil, ofType: nil)
        if let image {
            self.image = image
        }
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - SwiftUI wrapper

@MainActor
final class RichMarkdownController: ObservableObject {
    var toggleBold: () -> Void = {}
    var toggleItalic: () -> Void = {}
    var toggleUnderline: () -> Void = {}
    var toggleStrikethrough: () -> Void = {}
    var setHeading: (Int) -> Void = { _ in }
    var toggleTodo: () -> Void = {}
    var clearLinePrefix: () -> Void = {}
}

struct RichMarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var textSizeStep: Int
    var controller: RichMarkdownController
    var onScheduleSave: (String) -> Void
    var onRunAction: (EditAction) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let textView = MarkdownNSTextView()
        textView.delegate = context.coordinator
        textView.coordinator = context.coordinator
        textView.isRichText = true
        textView.allowsImageEditing = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 14)
        textView.textContainer?.lineFragmentPadding = 4

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = .width
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )

        context.coordinator.textView = textView
        context.coordinator.textSizeStep = textSizeStep
        context.coordinator.applyStyling(rawText: text, preserveCursor: false)
        wireController(context.coordinator)
        return scroll
    }

    private func wireController(_ coordinator: Coordinator) {
        controller.toggleBold = { [weak coordinator] in coordinator?.toggleBold() }
        controller.toggleItalic = { [weak coordinator] in coordinator?.toggleItalic() }
        controller.toggleUnderline = { [weak coordinator] in coordinator?.toggleUnderline() }
        controller.toggleStrikethrough = { [weak coordinator] in coordinator?.toggleStrikethrough() }
        controller.setHeading = { [weak coordinator] level in coordinator?.setHeading(level: level) }
        controller.toggleTodo = { [weak coordinator] in coordinator?.toggleTodo() }
        controller.clearLinePrefix = { [weak coordinator] in coordinator?.clearLinePrefix() }
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? MarkdownNSTextView else { return }
        context.coordinator.onScheduleSave = onScheduleSave
        context.coordinator.onRunAction = onRunAction
        wireController(context.coordinator)
        if context.coordinator.textSizeStep != textSizeStep {
            context.coordinator.textSizeStep = textSizeStep
            context.coordinator.applyStyling(rawText: context.coordinator.lastAppliedRaw, preserveCursor: true)
        }
        if context.coordinator.lastAppliedRaw != text {
            context.coordinator.applyStyling(rawText: text, preserveCursor: false)
            _ = textView // silence warning
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(binding: $text, onScheduleSave: onScheduleSave, onRunAction: onRunAction)
    }

    // MARK: Coordinator

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var binding: Binding<String>
        var onScheduleSave: (String) -> Void
        var onRunAction: (EditAction) -> Void
        weak var textView: MarkdownNSTextView?
        var lastAppliedRaw: String = ""
        var textSizeStep: Int = 0
        private var isApplyingStyling = false
        private var pendingRestyleTask: DispatchWorkItem?

        init(binding: Binding<String>,
             onScheduleSave: @escaping (String) -> Void,
             onRunAction: @escaping (EditAction) -> Void) {
            self.binding = binding
            self.onScheduleSave = onScheduleSave
            self.onRunAction = onRunAction
        }

        // MARK: NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard !isApplyingStyling, let textView else { return }
            let raw = extractRawMarkdown(from: textView.textStorage)

            binding.wrappedValue = raw
            lastAppliedRaw = raw
            onScheduleSave(raw)

            // Restyle on syntactic boundaries (space, newline, deletions) to keep the
            // visual rendering in sync with the markdown source without re-styling on
            // every keystroke.
            let last = raw.last
            let shouldRestyle = last == "\n" || last == " " || last == nil
            if shouldRestyle {
                scheduleRestyle()
            }
        }

        // MARK: - Formatting actions (called by toolbar / shortcuts)

        func toggleBold() { wrapSelection(open: "**", close: "**") }
        func toggleItalic() { wrapSelection(open: "*", close: "*") }
        func toggleUnderline() { wrapSelection(open: "<u>", close: "</u>") }
        func toggleStrikethrough() { wrapSelection(open: "~~", close: "~~") }

        func setHeading(level: Int) {
            let marker = String(repeating: "#", count: max(1, min(3, level))) + " "
            replaceLinePrefix(with: marker, removePrefixes: ["# ", "## ", "### ", "- [ ] ", "- [x] ", "- [X] ", "- ", "* ", "> "])
        }

        func toggleTodo() {
            replaceLinePrefix(with: "- [ ] ", removePrefixes: ["# ", "## ", "### ", "- [ ] ", "- [x] ", "- [X] ", "- ", "* ", "> "], toggleOff: "- [ ] ")
        }

        func clearLinePrefix() {
            replaceLinePrefix(with: "", removePrefixes: ["# ", "## ", "### ", "- [ ] ", "- [x] ", "- [X] ", "- ", "* ", "> "])
        }

        private func wrapSelection(open: String, close: String) {
            guard let textView else { return }
            let raw = lastAppliedRaw
            let styledRange = (textView.selectedRanges.first?.rangeValue) ?? NSRange(location: 0, length: 0)
            let rawStart = rawOffset(forStyledIndex: styledRange.location)
            let rawEnd = rawOffset(forStyledIndex: styledRange.location + styledRange.length)

            let nsRaw = raw as NSString
            let clampedEnd = min(max(rawEnd, rawStart), nsRaw.length)
            let clampedStart = min(rawStart, nsRaw.length)
            let selectedSubstring = nsRaw.substring(with: NSRange(location: clampedStart, length: clampedEnd - clampedStart))

            // Toggle off if already wrapped
            if selectedSubstring.hasPrefix(open) && selectedSubstring.hasSuffix(close),
               selectedSubstring.count >= open.count + close.count {
                let inner = String(selectedSubstring.dropFirst(open.count).dropLast(close.count))
                let newRaw = nsRaw.replacingCharacters(in: NSRange(location: clampedStart, length: clampedEnd - clampedStart), with: inner)
                applyRawChange(newRaw, restoreSelectionRaw: NSRange(location: clampedStart, length: inner.utf16.count))
                return
            }

            let insertion = open + selectedSubstring + close
            let newRaw = nsRaw.replacingCharacters(in: NSRange(location: clampedStart, length: clampedEnd - clampedStart), with: insertion)
            let cursorRaw = clampedStart + open.utf16.count + selectedSubstring.utf16.count
            applyRawChange(newRaw, restoreSelectionRaw: NSRange(location: cursorRaw, length: 0))
        }

        private func replaceLinePrefix(with newPrefix: String, removePrefixes: [String], toggleOff: String? = nil) {
            guard textView != nil else { return }
            let raw = lastAppliedRaw
            let styledRange = (textView?.selectedRanges.first?.rangeValue) ?? NSRange(location: 0, length: 0)
            let rawCursor = rawOffset(forStyledIndex: styledRange.location)

            // Find current line bounds in raw
            let nsRaw = raw as NSString
            var lineStart = 0
            var lineEnd = nsRaw.length
            if nsRaw.length > 0 {
                let cursor = min(rawCursor, nsRaw.length)
                // line start = position after the last \n before cursor (or 0)
                if cursor > 0 {
                    let searchRange = NSRange(location: 0, length: cursor)
                    let newlineRange = nsRaw.range(of: "\n", options: .backwards, range: searchRange)
                    lineStart = newlineRange.location == NSNotFound ? 0 : newlineRange.location + 1
                }
                let searchRange = NSRange(location: cursor, length: nsRaw.length - cursor)
                let newlineRange = nsRaw.range(of: "\n", options: [], range: searchRange)
                lineEnd = newlineRange.location == NSNotFound ? nsRaw.length : newlineRange.location
            }
            let line = nsRaw.substring(with: NSRange(location: lineStart, length: lineEnd - lineStart))

            // Strip any known leading prefix
            var stripped = line
            var hadToggleOffPrefix = false
            for prefix in removePrefixes where stripped.hasPrefix(prefix) {
                if let toggleOff, prefix == toggleOff {
                    hadToggleOffPrefix = true
                }
                stripped = String(stripped.dropFirst(prefix.count))
                break
            }

            let finalLine: String
            if hadToggleOffPrefix {
                finalLine = stripped // remove only
            } else {
                finalLine = newPrefix + stripped
            }

            let newRaw = nsRaw.replacingCharacters(in: NSRange(location: lineStart, length: lineEnd - lineStart), with: finalLine)
            // Place cursor at end of the new line content
            let cursorRaw = lineStart + finalLine.utf16.count
            applyRawChange(newRaw, restoreSelectionRaw: NSRange(location: cursorRaw, length: 0))
        }

        private func applyRawChange(_ newRaw: String, restoreSelectionRaw: NSRange) {
            binding.wrappedValue = newRaw
            applyStyling(rawText: newRaw, preserveCursor: false)
            let location = styledIndex(forRawOffset: restoreSelectionRaw.location)
            let endLocation = styledIndex(forRawOffset: restoreSelectionRaw.location + restoreSelectionRaw.length)
            textView?.setSelectedRange(NSRange(location: location, length: max(0, endLocation - location)))
            onScheduleSave(newRaw)
        }

        private func scheduleRestyle() {
            pendingRestyleTask?.cancel()
            let task = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.applyStyling(rawText: self.lastAppliedRaw, preserveCursor: true)
            }
            pendingRestyleTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: task)
        }

        // MARK: Round-trip

        func extractRawMarkdown(from storage: NSTextStorage?) -> String {
            guard let storage else { return "" }
            var result = ""
            storage.enumerateAttribute(
                .attachment,
                in: NSRange(location: 0, length: storage.length),
                options: []
            ) { value, range, _ in
                if let attachment = value as? MarkdownAttachment {
                    result += attachment.sourceMarkdown
                } else {
                    result += storage.attributedSubstring(from: range).string
                }
            }
            return result
        }

        /// Convert raw-text offset to styled-storage offset, accounting for attachments.
        func styledIndex(forRawOffset rawOffset: Int) -> Int {
            guard let storage = textView?.textStorage else { return 0 }
            var rawCursor = 0
            var styledCursor = 0
            storage.enumerateAttribute(
                .attachment,
                in: NSRange(location: 0, length: storage.length),
                options: []
            ) { value, range, stop in
                if rawCursor >= rawOffset {
                    stop.pointee = true
                    return
                }
                if let attachment = value as? MarkdownAttachment {
                    let attachLen = attachment.sourceMarkdown.utf16.count
                    if rawCursor + attachLen <= rawOffset {
                        rawCursor += attachLen
                        styledCursor += range.length // typically 1
                    } else {
                        stop.pointee = true
                    }
                } else {
                    let textLen = range.length
                    let take = min(textLen, rawOffset - rawCursor)
                    rawCursor += take
                    styledCursor += take
                    if take < textLen {
                        stop.pointee = true
                    }
                }
            }
            return styledCursor
        }

        /// Convert styled-storage offset to raw-text offset.
        func rawOffset(forStyledIndex index: Int) -> Int {
            guard let storage = textView?.textStorage else { return 0 }
            var rawOffset = 0
            var styledCursor = 0
            storage.enumerateAttribute(
                .attachment,
                in: NSRange(location: 0, length: storage.length),
                options: []
            ) { value, range, stop in
                if styledCursor >= index {
                    stop.pointee = true
                    return
                }
                let take = min(range.length, index - styledCursor)
                if let attachment = value as? MarkdownAttachment {
                    if take == range.length {
                        rawOffset += attachment.sourceMarkdown.utf16.count
                    }
                } else {
                    rawOffset += take
                }
                styledCursor += take
            }
            return rawOffset
        }

        // MARK: Styling

        func applyStyling(rawText: String, preserveCursor: Bool) {
            guard let textView, let storage = textView.textStorage else { return }
            isApplyingStyling = true
            defer { isApplyingStyling = false }

            let savedRawOffset: Int?
            if preserveCursor, let nsValue = textView.selectedRanges.first {
                savedRawOffset = rawOffset(forStyledIndex: nsValue.rangeValue.location)
            } else {
                savedRawOffset = nil
            }

            let attributed = buildAttributedString(from: rawText)
            storage.beginEditing()
            storage.setAttributedString(attributed)
            storage.endEditing()
            lastAppliedRaw = rawText

            if let savedRawOffset {
                let newIndex = min(styledIndex(forRawOffset: savedRawOffset), storage.length)
                textView.setSelectedRange(NSRange(location: newIndex, length: 0))
            }
        }

        // MARK: Markdown → AttributedString

        var baseFontSize: CGFloat { 16 + CGFloat(textSizeStep) * 2 }
        var baseFont: NSFont { NSFont.systemFont(ofSize: baseFontSize) }

        func buildAttributedString(from raw: String) -> NSAttributedString {
            let result = NSMutableAttributedString()
            let lines = raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            for (idx, line) in lines.enumerated() {
                result.append(styleLine(line))
                if idx < lines.count - 1 {
                    result.append(NSAttributedString(
                        string: "\n",
                        attributes: [
                            .font: baseFont,
                            .foregroundColor: NSColor.labelColor
                        ]
                    ))
                }
            }
            return result
        }

        private func styleLine(_ line: String) -> NSAttributedString {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Full-line image
            if let image = MarkdownImage.parse(trimmed) {
                let attachment = MarkdownAttachment(
                    kind: .image,
                    sourceMarkdown: line,
                    image: NSImage(contentsOf: image.url)
                )
                if let nsImage = NSImage(contentsOf: image.url) {
                    let maxWidth: CGFloat = 480
                    let ratio = nsImage.size.height / max(nsImage.size.width, 1)
                    let width = min(maxWidth, nsImage.size.width)
                    let height = width * ratio
                    attachment.bounds = NSRect(x: 0, y: 0, width: width, height: height)
                }
                return NSAttributedString(attachment: attachment)
            }

            // Todo. Attachment represents the marker. The trailing space stays as a real
            // character when present so round-trip stays exact.
            let leading = line.prefix { $0 == " " || $0 == "\t" }
            let bodyLine = String(line.dropFirst(leading.count))
            if let todo = MarkdownTodo.parse(bodyLine) {
                let marker = String(bodyLine.dropLast(todo.text.count)).trimmingCharacters(in: .whitespaces)
                let attachmentSource = String(leading) + marker
                let attachment = MarkdownAttachment(
                    kind: .todo(checked: todo.checked),
                    sourceMarkdown: attachmentSource,
                    image: todoImage(checked: todo.checked)
                )
                let height = baseFontSize + 2
                attachment.bounds = NSRect(x: 0, y: -3, width: height, height: height)
                let attr = NSMutableAttributedString(attachment: attachment)
                if !todo.text.isEmpty {
                    attr.append(NSAttributedString(
                        string: " ",
                        attributes: [.font: baseFont, .foregroundColor: NSColor.labelColor]
                    ))
                }
                attr.append(styledBody(todo.text, strikethrough: todo.checked, dimmed: todo.checked))
                return attr
            }

            // Headings
            if let parsedHeading = parseHeading(line) {
                return heading(prefix: parsedHeading.prefix, body: parsedHeading.text, level: parsedHeading.level)
            }

            // Quote
            if line.hasPrefix("> ") {
                let body = String(line.dropFirst(2))
                let italic = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: italic,
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
                let merged = NSMutableAttributedString(
                    string: "“ ",
                    attributes: [.font: italic, .foregroundColor: NSColor.tertiaryLabelColor]
                )
                merged.append(NSAttributedString(string: body, attributes: attrs))
                return merged
            }

            // Divider
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                let divider = NSAttributedString(
                    string: "──────────────────────",
                    attributes: [
                        .font: baseFont,
                        .foregroundColor: NSColor.quaternaryLabelColor
                    ]
                )
                return divider
            }

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                return NSAttributedString(
                    string: line,
                    attributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: baseFontSize - 1, weight: .regular),
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                )
            }

            // Bullet — same trick as todo: attachment is the "-" or "*", trailing space is real.
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                let prefix = String(line.prefix(2))
                let attachmentSource = String(prefix.dropLast())
                let body = String(line.dropFirst(2))
                let attachment = MarkdownAttachment(
                    kind: .bullet,
                    sourceMarkdown: attachmentSource,
                    image: bulletImage()
                )
                let height = baseFontSize
                attachment.bounds = NSRect(x: 0, y: -1, width: height * 0.6, height: height * 0.6)
                let attr = NSMutableAttributedString(attachment: attachment)
                attr.append(NSAttributedString(
                    string: " ",
                    attributes: [.font: baseFont, .foregroundColor: NSColor.labelColor]
                ))
                attr.append(styledBody(body))
                return attr
            }

            if let ordered = parseOrderedList(line) {
                let attr = NSMutableAttributedString(
                    string: ordered.marker + " ",
                    attributes: [
                        .font: baseFont,
                        .foregroundColor: NSColor.tertiaryLabelColor
                    ]
                )
                attr.append(styledBody(ordered.text))
                return attr
            }

            return styledBody(line)
        }

        private func parseHeading(_ line: String) -> (level: Int, prefix: String, text: String)? {
            var level = 0
            for character in line {
                guard character == "#" else { break }
                level += 1
            }
            guard (1...6).contains(level),
                  line.count > level,
                  line[line.index(line.startIndex, offsetBy: level)] == " " else {
                return nil
            }
            let prefix = String(repeating: "#", count: level) + " "
            return (level, prefix, String(line.dropFirst(level + 1)))
        }

        private func parseOrderedList(_ line: String) -> (marker: String, text: String)? {
            var cursor = line.startIndex
            var hasDigit = false
            while cursor < line.endIndex, line[cursor].isNumber {
                hasDigit = true
                cursor = line.index(after: cursor)
            }
            guard hasDigit, cursor < line.endIndex else { return nil }
            guard line[cursor] == "." || line[cursor] == ")" else { return nil }
            let afterDelimiter = line.index(after: cursor)
            guard afterDelimiter < line.endIndex, line[afterDelimiter] == " " else { return nil }
            let marker = String(line[...cursor])
            let bodyStart = line.index(after: afterDelimiter)
            return (marker, String(line[bodyStart...]))
        }

        private func heading(prefix: String, body: String, level: Int) -> NSAttributedString {
            let extra: CGFloat
            switch level {
            case 1: extra = 12
            case 2: extra = 6
            case 3: extra = 2
            case 4: extra = 0
            case 5: extra = -1
            default: extra = -2
            }
            let font = NSFont.boldSystemFont(ofSize: baseFontSize + extra)
            let merged = NSMutableAttributedString(
                string: prefix,
                attributes: [
                    .font: font,
                    .foregroundColor: NSColor.tertiaryLabelColor
                ]
            )
            merged.append(NSAttributedString(
                string: body,
                attributes: [
                    .font: font,
                    .foregroundColor: NSColor.labelColor
                ]
            ))
            return merged
        }

        private func styledBody(_ value: String,
                                strikethrough: Bool = false,
                                dimmed: Bool = false,
                                baseFontOverride: NSFont? = nil) -> NSAttributedString {
            let font = baseFontOverride ?? baseFont
            let baseColor: NSColor = dimmed ? .secondaryLabelColor : .labelColor

            let result = NSMutableAttributedString()
            let baseAttrs: [NSAttributedString.Key: Any] = {
                var attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: baseColor
                ]
                if strikethrough {
                    attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                    attrs[.strikethroughColor] = NSColor.secondaryLabelColor
                }
                return attrs
            }()
            let markerAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.quaternaryLabelColor
            ]

            applyInlineMarkup(
                value,
                into: result,
                baseFont: font,
                baseAttrs: baseAttrs,
                markerAttrs: markerAttrs,
                isBold: false,
                isItalic: false,
                isUnderline: false,
                isStrikethrough: strikethrough
            )
            return result
        }

        /// Parses inline markup (**bold**, *italic*, <u>…</u>, ~~strike~~) and writes styled
        /// runs into `result`. Markers remain visible but dimmed so the user can see what's there.
        private func applyInlineMarkup(
            _ value: String,
            into result: NSMutableAttributedString,
            baseFont: NSFont,
            baseAttrs: [NSAttributedString.Key: Any],
            markerAttrs: [NSAttributedString.Key: Any],
            isBold: Bool,
            isItalic: Bool,
            isUnderline: Bool,
            isStrikethrough: Bool
        ) {
            let chars = Array(value)
            var i = 0
            var run = ""

            func flushRun() {
                guard !run.isEmpty else { return }
                var attrs = baseAttrs
                var font = baseFont
                if isBold && isItalic {
                    font = NSFontManager.shared.convert(font, toHaveTrait: [.boldFontMask, .italicFontMask])
                } else if isBold {
                    font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                } else if isItalic {
                    font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                }
                attrs[.font] = font
                if isUnderline {
                    attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
                }
                if isStrikethrough {
                    attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                }
                result.append(NSAttributedString(string: run, attributes: attrs))
                run = ""
            }

            while i < chars.count {
                // Inline code: `…`
                if chars[i] == "`",
                   let close = findMarker(after: i + 1, in: chars, marker: "`"),
                   close != i + 1 {
                    flushRun()
                    result.append(NSAttributedString(string: "`", attributes: markerAttrs))
                    let inner = String(chars[(i + 1)..<close])
                    result.append(NSAttributedString(
                        string: inner,
                        attributes: codeAttrs(baseAttrs: baseAttrs)
                    ))
                    result.append(NSAttributedString(string: "`", attributes: markerAttrs))
                    i = close + 1
                    continue
                }
                // Bold: **…**
                if i + 1 < chars.count, chars[i] == "*", chars[i + 1] == "*",
                   let close = findMarker(after: i + 2, in: chars, marker: "**") {
                    flushRun()
                    result.append(NSAttributedString(string: "**", attributes: markerAttrs))
                    let inner = String(chars[(i + 2)..<close])
                    applyInlineMarkup(inner, into: result,
                                      baseFont: baseFont, baseAttrs: baseAttrs, markerAttrs: markerAttrs,
                                      isBold: true, isItalic: isItalic, isUnderline: isUnderline,
                                      isStrikethrough: isStrikethrough)
                    result.append(NSAttributedString(string: "**", attributes: markerAttrs))
                    i = close + 2
                    continue
                }
                // Italic: *…*
                if chars[i] == "*",
                   let close = findMarker(after: i + 1, in: chars, marker: "*"),
                   close != i + 1 {
                    flushRun()
                    result.append(NSAttributedString(string: "*", attributes: markerAttrs))
                    let inner = String(chars[(i + 1)..<close])
                    applyInlineMarkup(inner, into: result,
                                      baseFont: baseFont, baseAttrs: baseAttrs, markerAttrs: markerAttrs,
                                      isBold: isBold, isItalic: true, isUnderline: isUnderline,
                                      isStrikethrough: isStrikethrough)
                    result.append(NSAttributedString(string: "*", attributes: markerAttrs))
                    i = close + 1
                    continue
                }
                // Underline: <u>…</u>
                if i + 2 < chars.count, chars[i] == "<", chars[i + 1] == "u", chars[i + 2] == ">",
                   let close = findHtmlClose(after: i + 3, in: chars, tag: "u") {
                    flushRun()
                    result.append(NSAttributedString(string: "<u>", attributes: markerAttrs))
                    let inner = String(chars[(i + 3)..<close])
                    applyInlineMarkup(inner, into: result,
                                      baseFont: baseFont, baseAttrs: baseAttrs, markerAttrs: markerAttrs,
                                      isBold: isBold, isItalic: isItalic, isUnderline: true,
                                      isStrikethrough: isStrikethrough)
                    result.append(NSAttributedString(string: "</u>", attributes: markerAttrs))
                    i = close + 4
                    continue
                }
                // Strikethrough: ~~…~~
                if i + 1 < chars.count, chars[i] == "~", chars[i + 1] == "~",
                   let close = findMarker(after: i + 2, in: chars, marker: "~~") {
                    flushRun()
                    result.append(NSAttributedString(string: "~~", attributes: markerAttrs))
                    let inner = String(chars[(i + 2)..<close])
                    applyInlineMarkup(inner, into: result,
                                      baseFont: baseFont, baseAttrs: baseAttrs, markerAttrs: markerAttrs,
                                      isBold: isBold, isItalic: isItalic, isUnderline: isUnderline,
                                      isStrikethrough: true)
                    result.append(NSAttributedString(string: "~~", attributes: markerAttrs))
                    i = close + 2
                    continue
                }

                run.append(chars[i])
                i += 1
            }
            flushRun()
        }

        private func codeAttrs(baseAttrs: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
            var attrs = baseAttrs
            attrs[.font] = NSFont.monospacedSystemFont(ofSize: baseFontSize - 1, weight: .regular)
            attrs[.backgroundColor] = NSColor.controlBackgroundColor
            return attrs
        }

        private func findMarker(after start: Int, in chars: [Character], marker: String) -> Int? {
            let m = Array(marker)
            guard !m.isEmpty else { return nil }
            var i = start
            while i + m.count <= chars.count {
                if Array(chars[i..<(i + m.count)]) == m { return i }
                i += 1
            }
            return nil
        }

        private func findHtmlClose(after start: Int, in chars: [Character], tag: String) -> Int? {
            let close = Array("</\(tag)>")
            var i = start
            while i + close.count <= chars.count {
                if Array(chars[i..<(i + close.count)]) == close { return i }
                i += 1
            }
            return nil
        }

        // MARK: Icons

        private func todoImage(checked: Bool) -> NSImage? {
            let symbol = checked ? "checkmark.square.fill" : "square"
            let config = NSImage.SymbolConfiguration(
                pointSize: baseFontSize + 2,
                weight: .regular
            )
            let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
            img?.isTemplate = !checked
            if checked {
                return img?.tintedSolid(with: AppAccentColor.current.nsColor)
            }
            return img
        }

        private func bulletImage() -> NSImage? {
            let config = NSImage.SymbolConfiguration(
                pointSize: baseFontSize * 0.55,
                weight: .bold
            )
            let img = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
            return img?.tintedSolid(with: .tertiaryLabelColor)
        }

        // MARK: Toggle todo

        func toggleTodoAttachment(at styledIndex: Int) {
            guard let storage = textView?.textStorage,
                  styledIndex >= 0, styledIndex < storage.length,
                  let attachment = storage.attribute(.attachment, at: styledIndex, effectiveRange: nil) as? MarkdownAttachment,
                  case .todo = attachment.kind else { return }

            // Find which raw line this attachment is on by counting newlines in raw text
            // up to this attachment's raw offset.
            let raw = lastAppliedRaw
            let rawCursor = rawOffset(forStyledIndex: styledIndex)
            let upTo = String(raw.prefix(rawCursor))
            let lineIdx = upTo.filter { $0 == "\n" }.count

            var lines = raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            guard lineIdx < lines.count else { return }
            let line = lines[lineIdx]
            let leading = line.prefix { $0 == " " || $0 == "\t" }
            let body = String(line.dropFirst(leading.count))

            guard let updated = MarkdownTodo.toggledBody(body) else { return }

            lines[lineIdx] = String(leading) + updated
            let newRaw = lines.joined(separator: "\n")
            binding.wrappedValue = newRaw
            applyStyling(rawText: newRaw, preserveCursor: false)
            onScheduleSave(newRaw)
        }
    }
}

// MARK: - Custom NSTextView for click handling

final class MarkdownNSTextView: NSTextView {
    weak var coordinator: RichMarkdownTextView.Coordinator?

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let charIndex = characterIndex(at: point),
           charIndex < (textStorage?.length ?? 0),
           let attachment = textStorage?.attribute(.attachment, at: charIndex, effectiveRange: nil) as? MarkdownAttachment,
           case .todo = attachment.kind {
            coordinator?.toggleTodoAttachment(at: charIndex)
            return
        }
        super.mouseDown(with: event)
    }

    private func characterIndex(at point: NSPoint) -> Int? {
        guard let layoutManager, let textContainer else { return nil }
        let adjusted = NSPoint(
            x: point.x - textContainerOrigin.x,
            y: point.y - textContainerOrigin.y
        )
        var fraction: CGFloat = 0
        let glyphIndex = layoutManager.glyphIndex(
            for: adjusted,
            in: textContainer,
            fractionOfDistanceThroughGlyph: &fraction
        )
        return layoutManager.characterIndexForGlyph(at: glyphIndex)
    }
}

// MARK: - NSImage tint helper

extension NSImage {
    func tintedSolid(with color: NSColor) -> NSImage? {
        guard let copy = self.copy() as? NSImage else { return nil }
        copy.lockFocus()
        color.set()
        let rect = NSRect(origin: .zero, size: copy.size)
        rect.fill(using: .sourceAtop)
        copy.unlockFocus()
        copy.isTemplate = false
        return copy
    }
}
