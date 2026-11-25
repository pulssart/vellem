import SwiftUI

@MainActor
private final class ReplyDelivery: ObservableObject {
    static let shared = ReplyDelivery()
    @Published var drafts: [UUID: String] = {
        let saved = UserDefaults.standard.dictionary(forKey: "replyDrafts") as? [String: String] ?? [:]
        return Dictionary(uniqueKeysWithValues: saved.compactMap { key, value in UUID(uuidString: key).map { ($0, value) } })
    }() {
        didSet { UserDefaults.standard.set(Dictionary(uniqueKeysWithValues: drafts.filter { !$0.value.isEmpty }.map { ($0.key.uuidString, $0.value) }), forKey: "replyDrafts") }
    }
    @Published private(set) var sending = Set<UUID>()
    @Published private(set) var errors: [UUID: String] = [:]
    private var connections: [UUID: (token: UUID, connection: NSXPCConnection)] = [:]
    private struct Request: Codable { let id: UUID; let question: String }
    private var requests: [UUID: Request] = {
        guard let data = UserDefaults.standard.data(forKey: "replyRequests") else { return [:] }
        return (try? JSONDecoder().decode([UUID: Request].self, from: data)) ?? [:]
    }() {
        didSet {
            if let data = try? JSONEncoder().encode(requests) { UserDefaults.standard.set(data, forKey: "replyRequests") }
        }
    }

    func send(_ note: Note) {
        let id = note.id
        let text = drafts[id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
        guard note.conversation != nil, !text.isEmpty, !sending.contains(id) else { return }
        errors[id] = nil
        let request = requests[id].flatMap { $0.question == text ? $0.id : nil } ?? UUID()
        requests[id] = Request(id: request, question: text)
        let connection = NSXPCConnection(serviceName: ReplyServiceIdentity.name)
        connection.setCodeSigningRequirement("anchor apple generic and identifier \"com.adriendonot.Vellem.Replies\" and certificate leaf[subject.OU] = \"MKAFV9VL9V\"")
        connection.remoteObjectInterface = NSXPCInterface(with: VellemReplyServiceProtocol.self)
        // Per-connection token also distinguishes a retry of the same delivery.
        let token = UUID()
        let finish: @Sendable (String?) -> Void = { [weak self] error in
            Task { @MainActor in
                guard let self, let active = self.connections[id], active.token == token else { return }
                self.connections.removeValue(forKey: id)
                active.connection.invalidate()
                self.sending.remove(id)
                self.errors[id] = error
                if error == nil {
                    self.drafts[id] = nil
                    self.requests[id] = nil
                }
            }
        }
        connections[id] = (token, connection)
        sending.insert(id)
        let interrupted = "Connection interrupted. Check the conversation before retrying."
        connection.invalidationHandler = { finish(interrupted) }
        connection.interruptionHandler = { finish(interrupted) }
        connection.resume()
        let proxy = connection.remoteObjectProxyWithErrorHandler { _ in finish(interrupted) }
        (proxy as? VellemReplyServiceProtocol)?.send(noteID: id.uuidString, requestID: request.uuidString, question: text, completion: finish)
    }
}

struct ReplyComposer: View {
    let note: Note
    let conversation: ReplyConversation
    @Environment(\.locale) private var locale
    @ObservedObject private var delivery = ReplyDelivery.shared

    var body: some View {
        let sending = delivery.sending.contains(note.id)
        let draft = Binding(get: { delivery.drafts[note.id] ?? "" }, set: { delivery.drafts[note.id] = $0 })
        VStack(alignment: .leading, spacing: 7) {
            Divider()
            HStack(alignment: .bottom, spacing: 9) {
                Image(systemName: "arrowshape.turn.up.left")
                    .foregroundStyle(.secondary).padding(.bottom, 4).accessibilityHidden(true)
                TextField("Reply to \(conversation.provider.rawValue)…", text: draft, axis: .vertical)
                    .textFieldStyle(.plain).lineLimit(1...5).padding(.vertical, 4)
                    .disabled(sending)
                if sending {
                    ProgressView().controlSize(.small).accessibilityLabel("Sending reply")
                } else {
                    Button { delivery.send(note) } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 23))
                    }
                    .buttonStyle(.plain).accessibilityLabel("Send reply")
                    .help(conversation.provider == .codex ? "Send to the original chat (⌘↩). An open Codex chat uses its own permissions." : "Send reply (⌘↩)")
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(draft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, 16)
            if let error = delivery.errors[note.id] {
                Text(verbatim: VellemLanguage.serviceMessage(error, locale: locale)).font(.caption).foregroundStyle(.secondary)
                    .textSelection(.enabled).padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 10)
        .background(InboxPalette.paper)
    }
}
