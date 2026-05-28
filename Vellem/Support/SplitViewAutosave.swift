import AppKit
import SwiftUI

/// Injects an autosave name into the closest enclosing NSSplitView.
/// Add it as a background/overlay on an HSplitView to persist divider position across launches.
struct SplitViewAutosave: NSViewRepresentable {
    let name: String

    func makeNSView(context: Context) -> AutosaveProbe {
        AutosaveProbe(name: name)
    }

    func updateNSView(_ nsView: AutosaveProbe, context: Context) {}

    // MARK: -

    final class AutosaveProbe: NSView {
        let name: String

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

        private func inject() {
            var v: NSView? = superview
            while let cur = v {
                if let sv = cur as? NSSplitView, sv.autosaveName != name {
                    sv.autosaveName = name
                    return
                }
                v = cur.superview
            }
        }
    }
}
