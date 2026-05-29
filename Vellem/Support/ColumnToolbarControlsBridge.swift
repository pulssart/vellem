@preconcurrency import AppKit
import SwiftUI

struct ColumnToolbarControlsBridge: NSViewRepresentable {
    @Binding var showsUnreadOnly: Bool
    @Binding var showsPreview: Bool
    @Binding var showsProvenance: Bool
    @Binding var sortsNewestFirst: Bool

    var isVisible: Bool
    var canCreateNote: Bool
    var createNote: () -> Void

    func makeNSView(context: Context) -> ProbeView {
        let view = ProbeView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: ProbeView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.update()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class ProbeView: NSView {
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
        }

        required init?(coder: NSCoder) {
            fatalError()
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: ColumnToolbarControlsBridge
        private weak var probe: ProbeView?
        private weak var titlebarView: NSView?
        private weak var filterItem: NSView?
        private weak var displayItem: NSView?
        private weak var observedListPane: NSView?
        private var observers: [NSObjectProtocol] = []

        init(parent: ColumnToolbarControlsBridge) {
            self.parent = parent
            super.init()
        }

        func attach(to probe: ProbeView) {
            self.probe = probe
            DispatchQueue.main.async { [weak self] in
                self?.installIfNeeded()
            }
        }

        func update() {
            DispatchQueue.main.async { [weak self] in
                self?.installIfNeeded()
                self?.layoutNativePill()
            }
        }

        private func installIfNeeded() {
            guard let window = probe?.window,
                  let frameView = window.contentView?.superview
            else { return }

            if titlebarView !== frameView {
                titlebarView = frameView
                observe(window: window)
            }

            locateNativePill()
            layoutNativePill()
        }

        private func observe(window: NSWindow) {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()

            observers.append(NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.layoutNativePill()
                }
            })
        }

        private func observeListPane(_ listPane: NSView?) {
            guard observedListPane !== listPane else { return }

            if let observedListPane {
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSView.frameDidChangeNotification,
                    object: observedListPane
                )
            }

            observedListPane = listPane
            listPane?.postsFrameChangedNotifications = true

            if let listPane {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(listPaneFrameChanged(_:)),
                    name: NSView.frameDidChangeNotification,
                    object: listPane
                )
            }
        }

        @objc private func listPaneFrameChanged(_ notification: Notification) {
            layoutNativePill()
        }

        private func layoutNativePill() {
            guard parent.isVisible,
                  let probe,
                  let titlebarView
            else {
                filterItem?.isHidden = true
                displayItem?.isHidden = true
                observeListPane(nil)
                return
            }

            if filterItem == nil || displayItem == nil || filterItem?.window == nil || displayItem?.window == nil {
                locateNativePill()
            }

            guard let filterItem,
                  let displayItem
            else { return }

            observeListPane(probe)

            let listFrame = probe.convert(probe.bounds, to: titlebarView)
            let filterSize = resolvedSize(for: filterItem, fallback: NSSize(width: 45, height: 52))
            let displaySize = resolvedSize(for: displayItem, fallback: NSSize(width: 54, height: 52))
            let totalWidth = filterSize.width + displaySize.width
            let height = max(filterSize.height, displaySize.height)
            let rightInset: CGFloat = 18
            let topInset: CGFloat = 0
            let x = max(listFrame.minX + 120, listFrame.maxX - totalWidth - rightInset)
            let y = titlebarView.bounds.maxY - height - topInset

            filterItem.setFrameOrigin(NSPoint(x: x, y: y))
            filterItem.setFrameSize(filterSize)
            filterItem.isHidden = false

            displayItem.setFrameOrigin(NSPoint(x: x + filterSize.width, y: y))
            displayItem.setFrameSize(displaySize)
            displayItem.isHidden = false
        }

        private func locateNativePill() {
            guard let titlebarView else { return }

            filterItem = titlebarView.firstSubview(matchingAccessibilityText: "Unread only")
            displayItem = titlebarView.firstSubview(matchingAccessibilityText: "List display")
        }

        private func resolvedSize(for view: NSView, fallback: NSSize) -> NSSize {
            let fittingSize = view.fittingSize
            let frameSize = view.frame.size
            return NSSize(
                width: max(fittingSize.width, frameSize.width, fallback.width),
                height: max(fittingSize.height, frameSize.height, fallback.height)
            )
        }
    }
}

private extension NSView {
    func firstSubview(matchingAccessibilityText text: String) -> NSView? {
        if accessibilityIdentifier() == text ||
            accessibilityLabel() == text ||
            accessibilityHelp() == text ||
            accessibilityTitle() == text {
            return toolbarItemContainer
        }

        for subview in subviews {
            if let match = subview.firstSubview(matchingAccessibilityText: text) {
                return match
            }
        }

        return nil
    }

    var toolbarItemContainer: NSView {
        var current: NSView = self
        while let parent = current.superview,
              String(describing: type(of: parent)).contains("Toolbar") == false,
              parent.frame.width <= 120,
              parent.frame.height <= 80 {
            current = parent
        }
        return current
    }
}
