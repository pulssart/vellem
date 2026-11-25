import SwiftUI

enum InboxPalette {
    static let rail = Color.black
    static let frame = Color(white: 16 / 255)
    static let paper = Color.white
    static let header = Color(white: 0.97)
    static let selection = Color(white: 0.91)
    static let ink = Color(white: 0.09)
    static let muted = Color(white: 0.38)
    static let accent = Color("AccentColor")
}

/// Tracks the containing inbox window, including windows restored into full screen.
struct InboxFullScreenObserver: NSViewRepresentable {
    @Binding var isFullScreen: Bool

    func makeNSView(context: Context) -> ObserverView { ObserverView() }

    func updateNSView(_ view: ObserverView, context: Context) {
        view.onChange = { if isFullScreen != $0 { isFullScreen = $0 } }
    }

    final class ObserverView: NSView {
        var onChange: ((Bool) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            let center = NotificationCenter.default
            center.removeObserver(self)
            guard let window else { return }
            for name in [NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification] {
                center.addObserver(self, selector: #selector(updateMode), name: name, object: window)
            }
            // The initial attachment can occur during a SwiftUI update.
            DispatchQueue.main.async { [weak self] in self?.updateMode() }
        }

        @objc private func updateMode() {
            guard let window else { return }
            onChange?(window.styleMask.contains(.fullScreen))
        }
    }
}

struct InboxWindowMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let material = NSVisualEffectView()
        material.material = .sidebar
        material.blendingMode = .behindWindow
        material.state = .active
        material.appearance = NSAppearance(named: .vibrantDark)
        return material
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct RailButton<Icon: View>: View {
    let label: String
    let selected: Bool
    var hint: String? = nil
    var hasUnread = false
    let action: () -> Void
    @ViewBuilder var icon: () -> Icon
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            icon()
                .foregroundStyle(.white.opacity(selected || hovered ? 1 : 0.72))
                .frame(width: 42, height: 39)
                .background(.white.opacity(selected ? 0.16 : hovered ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topTrailing) {
                    if hasUnread { MailboxUnreadDot().padding(3) }
                }
                .overlay(alignment: .leading) {
                    if selected { Capsule().fill(.white).frame(width: 2, height: 14).offset(x: -6) }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).onHover { hovered = $0 }
        .help(LocalizedStringKey(hint ?? label)).accessibilityLabel(Text(LocalizedStringKey(label))).accessibilityHint(Text(LocalizedStringKey(hint ?? ""))).accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(hasUnread ? Text("Unread") : Text(""))
    }
}

struct AgentMark: View {
    let agent: InboxAgent?
    var size: CGFloat = 31
    var onRail = false

    var body: some View {
        ZStack {
            if !onRail && agent != .grokbot {
                RoundedRectangle(cornerRadius: size * 0.30).fill(.primary.opacity(0.07))
            }
            if agent == .grokbot {
                Image("InboxGrokbot").renderingMode(.original).resizable().scaledToFit()
            } else if let agent {
                Image("Inbox" + agent.rawValue).resizable().renderingMode(.template).scaledToFit()
                    .padding(onRail ? 0 : size * 0.21)
            } else { Image(systemName: "note.text").font(.system(size: size * 0.49)) }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension Note {
    var inboxSender: String {
        InboxAgent.origin(of: self)?.rawValue ?? sourceApp ?? sourceURL?.host ?? "Vellem"
    }
}

struct InboxMessageRow: View {
    let note: Note
    let agent: InboxAgent?
    let showsPreview: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AgentMark(agent: agent)
                .overlay(alignment: .topLeading) {
                    if !note.isRead {
                        Circle().fill(InboxPalette.ink).frame(width: 8, height: 8)
                            .overlay(Circle().stroke(InboxPalette.paper, lineWidth: 1.5))
                            .offset(x: -2, y: -2)
                    }
                }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(agent?.rawValue ?? note.inboxSender).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Spacer(minLength: 5)
                    Text(note.updatedAt, format: Calendar.current.isDateInToday(note.updatedAt)
                         ? .dateTime.hour().minute() : .dateTime.month(.abbreviated).day())
                        .font(.system(size: 10)).foregroundStyle(InboxPalette.muted)
                }
                Text(note.title).font(.system(size: 13, weight: note.isRead ? .regular : .semibold))
                    .lineLimit(1)
                if showsPreview {
                    Text(note.preview).font(.system(size: 12)).foregroundStyle(InboxPalette.muted).lineLimit(1)
                }
            }
        }.foregroundStyle(InboxPalette.ink)
        .padding(.horizontal, 13).padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(note.isRead ? "" : "Unread")
    }
}

extension View {
    func inboxActionGroup() -> some View {
        padding(.horizontal, 5).frame(height: 30)
            .background(InboxPalette.paper, in: Capsule())
            .overlay(Capsule().strokeBorder(.primary.opacity(0.14)))
    }

    func inboxPanel() -> some View {
        background(InboxPalette.paper)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct InboxEnvelope: View {
    let note: Note
    let agent: InboxAgent?
    let folder: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            Text(note.title)
                .font(.system(size: 26, weight: .semibold)).tracking(-0.6)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 10) {
                AgentMark(agent: agent, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent?.rawValue ?? note.inboxSender).font(.system(size: 13, weight: .semibold))
                    if let folder {
                        Text(folder).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    } else if let host = note.sourceURL?.host {
                        Text(host).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Text(note.updatedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.caption).foregroundStyle(.secondary)
            }
            Divider()
        }.padding(.bottom, 15)
    }
}
