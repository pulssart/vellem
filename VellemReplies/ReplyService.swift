import Foundation

/// launchd starts this listener only when the signed Vellem app connects.
final class ReplyService: NSObject, NSXPCListenerDelegate, VellemReplyServiceProtocol, @unchecked Sendable {
    private let mobileMailbox = MobileMailboxRelay()

    func refreshMobileMailbox(completion: @escaping @Sendable () -> Void) {
        mobileMailbox.refresh(using: self, completion: completion)
    }

    private let lock = NSLock()
    private var busySessions = Set<UUID>()

    static func run() {
        let service = ReplyService()
        let listener = NSXPCListener.service()
        listener.delegate = service
        withExtendedLifetime(service) { listener.resume() }
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.setCodeSigningRequirement("anchor apple generic and identifier \"com.adriendonot.Vellem\" and certificate leaf[subject.OU] = \"MKAFV9VL9V\"")
        connection.exportedInterface = NSXPCInterface(with: VellemReplyServiceProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    func send(noteID: String, requestID: String, question: String, completion: @escaping @Sendable (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let id = UUID(uuidString: noteID), let request = UUID(uuidString: requestID),
                      !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw MCPError.invalidArguments("Enter a reply before sending.")
                }
                let store = NotesFileStore()
                guard let note = try store.getNote(id: id), let conversation = note.conversation else {
                    throw MCPError.notFound("This message has no linked CLI conversation.")
                }
                guard self.lock.withLock({ self.busySessions.insert(conversation.sessionID).inserted }) else {
                    throw MCPError.invalidArguments("A reply is already running in this conversation.")
                }
                defer { _ = self.lock.withLock { self.busySessions.remove(conversation.sessionID) } }
                if try store.getNote(id: id)?.replies?.contains(where: { $0.id == request }) != true {
                    do {
                        let answer = try ReplyCLI.answer(to: question, about: note, in: conversation)
                        let reply = NoteReply(id: request, question: question, answer: answer, date: Date())
                        try store.appendReply(reply, to: id, in: conversation)
                    } catch MCPError.codexActiveWriter where conversation.provider == .codex {
                        let client = try CodexReplyQueue()
                        var reply = NoteReply(id: request, question: question,
                                              answer: "En attente de la réponse du chat Codex…", date: .now, delivery: .queued)
                        guard try store.appendReply(reply, to: id, in: conversation) else {
                            completion(nil)
                            return
                        }
                        do {
                            try client.submit(reply, note: note, thread: conversation.sessionID)
                        } catch let error as CodexQueueRejection {
                            reply.delivery = .failed
                            reply.answer = error.message
                            try store.appendReply(reply, to: id, in: conversation)
                        } catch {
                            // The connection may have dropped after Codex accepted the request.
                            // Reconcile by client message ID instead of sending it again.
                            NSLog("Vellem: confirmation de mise en file Codex indisponible.")
                        }
                    }
                }
                completion(nil)
            } catch {
                completion(error.localizedDescription)
            }
        }
    }
}
