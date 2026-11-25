import Darwin
import Foundation

struct CodexQueueRejection: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// A separate desktop client can post to the owning Codex session without resuming it.
final class CodexReplyQueue {
    private typealias Object = [String: Any]
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private var buffer = Data()
    private var serial = 0

    init() throws {
        process.executableURL = try ReplyCLI.executable(for: .codex)
        process.arguments = ["app-server", "--stdio"]
        process.environment = ReplyCLI.environment
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        _ = try call("initialize", ["clientInfo": ["name": "vellem", "version": "1"],
                                     "capabilities": ["experimentalApi": true]])
        try write(["method": "initialized"])
    }

    deinit {
        try? input.fileHandleForWriting.close()
        if process.isRunning { process.terminate() }
    }

    func submit(_ reply: NoteReply, note: Note, thread: UUID) throws {
        let result = try call("thread/queue/add", [
            "threadId": thread.uuidString.lowercased(),
            "clientUserMessageId": reply.id.uuidString.lowercased(),
            "input": [["type": "text", "text": try ReplyCLI.prompt(to: reply.question, about: note)]]
        ])
        guard let item = result["queuedSubmission"] as? Object, matches(item["clientUserMessageId"], reply.id) else {
            throw MCPError.io("Codex n’a pas confirmé la mise en file du message.")
        }
    }

    enum Status { case waiting, absent, finished(NoteReply) }

    func status(of pending: NoteReply, thread: UUID) throws -> Status {
        let id = thread.uuidString.lowercased()
        var params: Object = ["threadId": id, "itemsView": "summary", "limit": 5, "sortDirection": "desc"]
        var reachedEarlierTurns = false
        repeat {
            let page = try call("thread/turns/list", params)
            guard let turns = page["data"] as? [Object] else { throw protocolError }
            for turn in turns {
                let items = turn["items"] as? [Object] ?? []
                if items.contains(where: { matches($0["clientId"], pending.id) }), let turnID = turn["id"] as? String {
                    // A reader outside the owning app sees unfinished turns as "interrupted"
                    // until the owner persists a completion timestamp.
                    guard turn["completedAt"] is NSNumber else { return .waiting }
                    var reply = pending
                    switch turn["status"] as? String {
                    case "completed":
                        guard let answer = try finalAnswer(thread: id, turn: turnID) else {
                            reply.delivery = .failed
                            reply.answer = "Codex a terminé ce tour sans réponse écrite."
                            return .finished(reply)
                        }
                        reply.answer = answer
                        reply.delivery = nil
                    case "failed", "interrupted":
                        reply.delivery = .failed
                        let message = (turn["error"] as? Object)?["message"] as? String
                        reply.answer = message.map { ReplyCLI.codexError($0, exitStatus: 0).localizedDescription }
                            ?? "Le tour a été interrompu dans Codex."
                    default: return .waiting
                    }
                    return .finished(reply)
                }
                if let timestamp = turn["startedAt"] as? Double, timestamp < pending.date.timeIntervalSince1970 - 5 {
                    reachedEarlierTurns = true
                    break
                }
            }
            guard !reachedEarlierTurns, let cursor = page["nextCursor"] as? String else { break }
            params["cursor"] = cursor
        } while true

        // Allow the owner to move a submission from its queue into persisted history.
        if Date().timeIntervalSince(pending.date) > 90 {
            let queued = try call("thread/queue/list", ["threadId": id])
            if let entries = queued["data"] as? [Object], queued["nextCursor"] as? String == nil,
               !entries.contains(where: { matches($0["clientUserMessageId"], pending.id) }) {
                return .absent
            }
        }
        return .waiting
    }

    private func finalAnswer(thread: String, turn: String) throws -> String? {
        var params: Object = ["threadId": thread, "turnId": turn, "limit": 12, "sortDirection": "desc"]
        repeat {
            let page = try call("thread/items/list", params)
            guard let items = page["data"] as? [Object] else { throw protocolError }
            for entry in items {
                guard let item = entry["item"] as? Object, item["type"] as? String == "agentMessage" else { continue }
                let phase = item["phase"] as? String
                if phase == nil || phase == "final_answer", let text = item["text"] as? String, !text.isEmpty { return text }
            }
            guard let cursor = page["nextCursor"] as? String else { return nil }
            params["cursor"] = cursor
        } while true
    }

    private func matches(_ value: Any?, _ id: UUID) -> Bool {
        (value as? String).flatMap(UUID.init(uuidString:)) == id
    }

    private var protocolError: MCPError { .io("Réponse inattendue du service local de Codex.") }

    private func write(_ message: Object) throws {
        var data = try JSONSerialization.data(withJSONObject: message)
        data.append(10)
        try input.fileHandleForWriting.write(contentsOf: data)
    }

    private func call(_ method: String, _ params: Object) throws -> Object {
        serial += 1
        try write(["id": serial, "method": method, "params": params])
        let deadline = ProcessInfo.processInfo.systemUptime + 20
        while ProcessInfo.processInfo.systemUptime < deadline {
            if let end = buffer.firstIndex(of: 10) {
                let line = buffer[..<end]
                buffer.removeSubrange(...end)
                guard let message = try JSONSerialization.jsonObject(with: line) as? Object,
                      message["id"] as? Int == serial else { continue }
                if let error = message["error"] as? Object {
                    if error["code"] as? Int == -32601 {
                        throw CodexQueueRejection(message: "Cette version de Codex ne prend pas en charge les réponses aux chats ouverts. Mets Codex à jour.")
                    }
                    throw CodexQueueRejection(message: ReplyCLI.codexError(error["message"] as? String ?? "", exitStatus: 0).localizedDescription)
                }
                guard let result = message["result"] as? Object else { throw protocolError }
                return result
            }
            let fd = output.fileHandleForReading.fileDescriptor
            var watch = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let remaining = max(1, Int32((deadline - ProcessInfo.processInfo.systemUptime) * 1000))
            let ready = poll(&watch, 1, remaining)
            if ready < 0 && errno == EINTR { continue }
            guard ready > 0 else { break }
            var bytes = [UInt8](repeating: 0, count: 32768)
            let count = read(fd, &bytes, bytes.count)
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { throw protocolError }
            buffer.append(contentsOf: bytes.prefix(count))
        }
        throw MCPError.io("Le service local de Codex ne répond pas.")
    }
}
