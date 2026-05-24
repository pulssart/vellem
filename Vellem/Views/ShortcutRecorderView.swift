import AppKit
import Carbon
import SwiftUI

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var keyCode: Int
    @Binding var modifiers: Int

    func makeNSView(context: Context) -> RecorderControl {
        let control = RecorderControl()
        control.onChange = { shortcut in
            keyCode = Int(shortcut.keyCode)
            modifiers = Int(shortcut.modifiers)
        }
        return control
    }

    func updateNSView(_ nsView: RecorderControl, context: Context) {
        nsView.shortcut = AppShortcut(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers)).normalized
    }
}

final class RecorderControl: NSControl {
    var shortcut = AppPreferences.quickCaptureShortcut {
        didSet {
            needsDisplay = true
        }
    }

    var onChange: ((AppShortcut) -> Void)?
    private var isRecording = false

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 220, height: 28) }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        let carbonModifiers = ShortcutFormatter.carbonModifiers(from: event.modifierFlags)
        guard carbonModifiers != 0 else {
            NSSound.beep()
            return
        }

        shortcut = AppShortcut(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers).normalized
        onChange?(shortcut)
        isRecording = false
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        needsDisplay = true
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        NSColor.controlBackgroundColor.setFill()
        path.fill()

        (isRecording ? NSColor.keyboardFocusIndicatorColor : NSColor.separatorColor).setStroke()
        path.lineWidth = isRecording ? 2 : 1
        path.stroke()

        let text = isRecording ? "Type shortcut" : ShortcutFormatter.string(for: shortcut)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let rect = NSRect(
            x: bounds.minX + 10,
            y: bounds.midY - attributed.size().height / 2,
            width: bounds.width - 20,
            height: attributed.size().height
        )
        attributed.draw(in: rect)
    }
}
