import SwiftUI
import UIKit

extension InboxAgent {
    static let mobileMailboxOrder: [Self] = [.codex, .claude, .gemini, .chatGPT, .grokbot, .grok]
}

struct MobileInboxDrawer: ViewModifier {
    @Binding var isOpen: Bool
    let enabled: Bool
    let scope: MailScope
    let hasUnread: (MailScope) -> Bool
    let select: (MailScope) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var translation: CGFloat = 0
    private let width: CGFloat = 84

    private var offset: CGFloat {
        guard enabled else { return 0 }
        return min(width, max(0, (isOpen ? width : 0) + translation))
    }

    func body(content: Content) -> some View {
        let progress = offset / width
        ZStack(alignment: .leading) {
            if enabled {
                rail
                    .allowsHitTesting(isOpen)
                    .accessibilityHidden(!isOpen)
            }
            ZStack {
                content
                    .environment(\.colorScheme, enabled ? .light : colorScheme)
                    .allowsHitTesting(!isOpen)
                    .accessibilityHidden(isOpen)
                if isOpen {
                    Button { settle(false) } label: {
                        Color.black.opacity(0.035).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close agent inboxes")
                    .accessibilityIdentifier("closeMailboxRail")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: progress * 18, style: .continuous))
            .offset(x: offset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .background {
            (enabled ? Color(white: 1 - progress) : MobileStyle.graphite)
                .ignoresSafeArea(.container)
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: isOpen)
        .background {
            if enabled {
                MailboxPan(isOpen: isOpen, changed: { translation = $0 }, ended: finishDrag)
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: enabled) { _, available in
            if !available { isOpen = false; translation = 0 }
        }
    }

    private var rail: some View {
        ScrollView(.vertical) {
            VStack(spacing: 4) {
                railButton(.all, label: "All inboxes", id: "all") {
                    Image(systemName: "tray.2").font(.system(size: 26, weight: .medium))
                }
                Rectangle().fill(.white.opacity(0.18)).frame(width: 32, height: 1)
                    .padding(.vertical, 6).accessibilityHidden(true)
                ForEach(InboxAgent.mobileMailboxOrder, id: \.self) { agent in
                    railButton(.agent(agent), label: agent.rawValue, id: agent.rawValue) {
                        Image("Inbox" + agent.rawValue)
                            .resizable().renderingMode(agent == .grokbot ? .original : .template)
                            .scaledToFit().frame(width: 30, height: 30)
                    }
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .frame(width: width).frame(maxHeight: .infinity)
        .background(.black)
        .accessibilityAction(.escape) { settle(false) }
    }

    private func railButton(_ destination: MailScope, label: String, id: String,
                            @ViewBuilder icon: () -> some View) -> some View {
        let selected = scope == destination
        let unread = hasUnread(destination)
        return Button {
            select(destination)
            isOpen = false
        } label: {
            icon().foregroundStyle(selected ? .black : .white)
                .frame(width: 48, height: 48)
                .background(selected ? Color.white : .clear, in: RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .topTrailing) {
                    if unread { MailboxUnreadDot().padding(3) }
                }
                .frame(width: 68, height: 54).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(label)))
        .accessibilityValue(unread ? "Unread messages" : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("rail." + id)
    }

    private func finishDrag(distance: CGFloat, velocity: CGFloat, cancelled: Bool) {
        let direction: CGFloat = isOpen ? -1 : 1
        let travelled = distance * direction
        let shouldSwitch = travelled >= 30 || (travelled >= 15 && velocity * direction >= 260)
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
            if !cancelled && shouldSwitch { settle(!isOpen) }
            translation = 0
        }
    }

    private func settle(_ open: Bool) {
        guard isOpen != open else { return }
        MobileHaptics.shared.selectionChanged()
        isOpen = open
    }
}

private struct MailboxPan: UIViewRepresentable {
    let isOpen: Bool
    let changed: (CGFloat) -> Void
    let ended: (CGFloat, CGFloat, Bool) -> Void

    func makeUIView(context: Context) -> Anchor {
        let view = Anchor()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: Anchor, context: Context) { view.gesture = self }
    static func dismantleUIView(_ view: Anchor, coordinator: ()) { view.detach() }

    final class Anchor: UIView, UIGestureRecognizerDelegate {
        var gesture: MailboxPan?
        private lazy var pan: UIPanGestureRecognizer = {
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(track(_:)))
            recognizer.maximumNumberOfTouches = 1
            recognizer.delegate = self
            return recognizer
        }()

        override func didMoveToWindow() {
            super.didMoveToWindow()
            detach()
            // The window sees the same touch as a message row. A recognized pan
            // cancels the row tap; vertical scrolling keeps its native recognizer.
            window?.addGestureRecognizer(pan)
        }

        func detach() { pan.view?.removeGestureRecognizer(pan) }

        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let gesture, bounds.contains(pan.location(in: self)) else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) * 1.25 && (gesture.isOpen ? velocity.x < 0 : velocity.x > 0)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let scroll = otherGestureRecognizer.view as? UIScrollView else { return false }
            return otherGestureRecognizer === scroll.panGestureRecognizer
        }

        @objc private func track(_ recognizer: UIPanGestureRecognizer) {
            let distance = recognizer.translation(in: recognizer.view).x
            switch recognizer.state {
            case .began, .changed: gesture?.changed(distance)
            case .ended: gesture?.ended(distance, recognizer.velocity(in: recognizer.view).x, false)
            case .cancelled, .failed: gesture?.ended(0, 0, true)
            default: break
            }
        }
    }
}
