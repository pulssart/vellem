import AppKit
import QuartzCore
import SwiftUI

struct QuickCaptureWindowConfigurator: NSViewRepresentable {
    var floatsAboveOtherWindows: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window, coordinator: context.coordinator)
        }
    }

    private func configure(window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }
        window.level = floatsAboveOtherWindows ? .floating : .normal
        window.collectionBehavior.insert(.fullScreenAuxiliary)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = true
        window.backgroundColor = Self.surfaceColor
        window.hasShadow = true
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.insert(.resizable)
        window.titlebarSeparatorStyle = .none
        window.minSize = NSSize(width: 360, height: 240)
        paintWindowFrame(window)
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false

        coordinator.animateArrivalIfNeeded(for: window)
    }

    private func paintWindowFrame(_ window: NSWindow) {
        let backgroundColor = Self.surfaceColor.cgColor
        let views = [
            window.contentView,
            window.contentView?.superview,
            window.standardWindowButton(.closeButton)?.superview,
            window.standardWindowButton(.closeButton)?.superview?.superview
        ]

        views.forEach { view in
            view?.wantsLayer = true
            view?.layer?.backgroundColor = backgroundColor
        }
    }

    private static var surfaceColor: NSColor {
        NSColor(calibratedRed: 1.0, green: 0.94, blue: 0.70, alpha: 1.0)
    }

    final class Coordinator {
        private var animatedWindowIDs = Set<ObjectIdentifier>()

        @MainActor
        func animateArrivalIfNeeded(for window: NSWindow) {
            let id = ObjectIdentifier(window)
            guard !animatedWindowIDs.contains(id) else { return }
            animatedWindowIDs.insert(id)

            let finalFrame = window.frame
            let startFrame = finalFrame.offsetBy(dx: 0, dy: -12)

            window.alphaValue = 0
            window.setFrame(startFrame, display: false)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 1
                window.animator().setFrame(finalFrame, display: true)
            }
        }
    }
}
