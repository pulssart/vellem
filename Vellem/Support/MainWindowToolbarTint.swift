@preconcurrency import AppKit
import SwiftUI

struct MainWindowToolbarTint: NSViewRepresentable {
    var isEnabled: Bool
    var accent: AppAccentColor

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.configure(window: view.window, isEnabled: isEnabled, accent: accent)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.configure(window: nsView.window, isEnabled: isEnabled, accent: accent)
        }
    }

    @MainActor
    final class Coordinator {
        private weak var observedWindow: NSWindow?
        private var observers: [NSObjectProtocol] = []

        deinit {
            observers.forEach(NotificationCenter.default.removeObserver)
        }

        func configure(window: NSWindow?, isEnabled: Bool, accent: AppAccentColor) {
            guard let window else { return }
            observe(window)

            let tint = isEnabled ? toolbarTint(for: window, accent: accent) : nil
            paintTitlebar(window, tint: tint)
        }

        private func observe(_ window: NSWindow) {
            guard observedWindow !== window else { return }

            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            observedWindow = window

            let names: [Notification.Name] = [
                NSWindow.didEnterFullScreenNotification,
                NSWindow.didExitFullScreenNotification,
                NSWindow.didResizeNotification
            ]

            observers = names.map { name in
                NotificationCenter.default.addObserver(
                    forName: name,
                    object: window,
                    queue: .main
                ) { [weak self, weak window] _ in
                    Task { @MainActor in
                        guard let self, let window else { return }
                        self.paintTitlebar(window, tint: self.currentTint(for: window))
                    }
                }
            }
        }

        private func currentTint(for window: NSWindow) -> NSColor? {
            guard UserDefaults.standard.bool(forKey: AppPreferences.colorTopBarKey) else { return nil }
            return toolbarTint(for: window, accent: AppAccentColor.current)
        }

        private func toolbarTint(for window: NSWindow, accent: AppAccentColor) -> NSColor {
            var tint = accent.nsColor.withAlphaComponent(0.28)
            window.effectiveAppearance.performAsCurrentDrawingAppearance {
                let base = NSColor.windowBackgroundColor.usingColorSpace(.deviceRGB) ?? .windowBackgroundColor
                let color = accent.nsColor.usingColorSpace(.deviceRGB) ?? accent.nsColor
                tint = color.blended(withFraction: 0.72, of: base) ?? color.withAlphaComponent(0.28)
            }
            return tint
        }

        private func paintTitlebar(_ window: NSWindow, tint: NSColor?) {
            let cgColor = tint?.cgColor
            let titlebarViews = [
                window.contentView?.superview,
                window.standardWindowButton(.closeButton)?.superview,
                window.standardWindowButton(.closeButton)?.superview?.superview
            ]

            titlebarViews.forEach { view in
                view?.wantsLayer = true
                view?.layer?.backgroundColor = cgColor
            }
        }
    }
}
