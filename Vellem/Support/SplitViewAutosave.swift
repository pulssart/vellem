import AppKit
import SwiftUI

/// Injects an autosave name into the closest enclosing NSSplitView.
/// Add it as a background or overlay on a split column to persist divider positions across launches.
struct SplitViewAutosave: NSViewRepresentable {
    let name: String

    func makeNSView(context: Context) -> AutosaveProbe {
        AutosaveProbe(name: name)
    }

    func updateNSView(_ nsView: AutosaveProbe, context: Context) {
        nsView.name = name
        nsView.inject()
    }

    // MARK: -

    final class AutosaveProbe: NSView {
        var name: String
        private var pendingRetryCount = 0

        init(name: String) {
            self.name = name
            super.init(frame: .zero)
            isHidden = true
        }

        required init?(coder: NSCoder) { fatalError() }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            inject()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            inject()
        }

        func inject() {
            var v: NSView? = superview
            while let cur = v {
                if let sv = cur as? NSSplitView {
                    if sv.autosaveName != name {
                        sv.autosaveName = name
                    }
                    pendingRetryCount = 0
                    return
                }
                v = cur.superview
            }

            retryIfNeeded()
        }

        private func retryIfNeeded() {
            guard window != nil, pendingRetryCount < 3 else { return }

            pendingRetryCount += 1
            DispatchQueue.main.async { [weak self] in
                self?.inject()
            }
        }
    }
}
