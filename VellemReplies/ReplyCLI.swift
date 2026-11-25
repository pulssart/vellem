import AppKit
import Foundation

enum ReplyCLI {
    private static var binDirectories: [String] {
        [FileManager.default.homeDirectoryForCurrentUser.path + "/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
    }

    static func executable(for provider: ReplyConversation.Provider) throws -> URL {
        let fm = FileManager.default
        let name = provider.rawValue.lowercased()
        var candidates = binDirectories.map { URL(fileURLWithPath: $0).appendingPathComponent(name) }
        if provider == .codex,
           let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex"),
           let resources = Bundle(url: app)?.resourceURL {
            // Desktop and the standalone CLI can have different model catalogs for the same account.
            candidates.insert(contentsOf: [
                resources.appending(path: "codex-cli/CodexCLI.app/Contents/MacOS/codex"),
                resources.appending(path: "codex")
            ], at: 0)
        }
        guard let executable = candidates.first(where: { fm.isExecutableFile(atPath: $0.path) }) else {
            throw MCPError.notFound("Install the " + provider.rawValue + " CLI on this Mac to reply.")
        }
        return executable
    }

    static var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["USER"] = NSUserName()
        env["LOGNAME"] = NSUserName()
        env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
        env["PATH"] = (binDirectories + [env["PATH"] ?? ""]).joined(separator: ":")
        return env
    }

    static func answer(to question: String, about note: Note, in conversation: ReplyConversation) throws -> String {
        let fm = FileManager.default
        let executable = try executable(for: conversation.provider)
        var isDirectory: ObjCBool = false
        guard conversation.directory.hasPrefix("/"), fm.fileExists(atPath: conversation.directory, isDirectory: &isDirectory),
              isDirectory.boolValue else { throw MCPError.notFound("The original project folder is unavailable on this Mac.") }

        let scratch = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: scratch, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? fm.removeItem(at: scratch) }

        let input = scratch.appendingPathComponent("question")
        let output = scratch.appendingPathComponent("response")
        let diagnostics = scratch.appendingPathComponent("diagnostics")
        let prompt = try prompt(to: question, about: note)
        try Data(prompt.utf8).write(to: input)
        try Data().write(to: output)
        try Data().write(to: diagnostics)
        let stdin = try FileHandle(forReadingFrom: input)
        let stdout = try FileHandle(forWritingTo: output)
        let stderr = try FileHandle(forWritingTo: diagnostics)
        defer { try? stdin.close(); try? stdout.close(); try? stderr.close() }

        let id = conversation.sessionID.uuidString.lowercased()
        let proc = Process()
        proc.executableURL = executable
        proc.currentDirectoryURL = URL(fileURLWithPath: conversation.directory, isDirectory: true)
        proc.environment = environment
        switch conversation.provider {
        case .codex:
            proc.arguments = ["exec", "--ignore-user-config", "--sandbox", "read-only", "-c", "approval_policy=\"never\"", "--skip-git-repo-check", "resume", "--json", id, "-"]
        case .claude:
            proc.arguments = ["-p", "--resume", id, "--output-format", "json", "--tools", "", "--strict-mcp-config"]
        }
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr
        let finished = DispatchSemaphore(value: 0)
        proc.terminationHandler = { _ in finished.signal() }
        try proc.run()
        if finished.wait(timeout: .now() + 300) == .timedOut {
            if proc.isRunning { proc.terminate() }
            if finished.wait(timeout: .now() + 3) == .timedOut, proc.isRunning { kill(proc.processIdentifier, SIGKILL) }
            throw MCPError.io("The CLI timed out. Check the original conversation before retrying.")
        }
        let bytes = try Data(contentsOf: output)
        let diagnosticText = proc.terminationStatus == 0 ? "" : (try? String(contentsOf: diagnostics, encoding: .utf8)) ?? ""
        return try parse(bytes, conversation: conversation, exitStatus: proc.terminationStatus, diagnostics: diagnosticText)
    }

    static func prompt(to question: String, about note: Note) throws -> String {
        // Only the user's explicit reply is an instruction. The report title is quoted for reference.
        let title = String(decoding: try JSONEncoder().encode(note.title), as: UTF8.self)
        return """
        The user is replying to your Vellem delivery \(note.id.uuidString), titled \(title).
        Answer directly here. Vellem will attach your response to the report.

        \(question)
        """
    }

    // A completed turn can also contain warnings from individual tools. Only a terminal failure
    // describes the reply itself. Early CLI startup failures are reported on stderr instead.
    private static func codexTurnFailure(in bytes: Data, failedExit: Bool) -> String? {
        var lastError: String?
        for line in bytes.split(separator: 10).reversed() {
            guard let event = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else { continue }
            switch event["type"] as? String {
            case "turn.completed": return nil
            case "turn.failed":
                return (event["error"] as? [String: Any])?["message"] as? String ?? lastError ?? ""
            case "error" where failedExit && lastError == nil:
                lastError = event["message"] as? String
            default: continue
            }
        }
        return lastError
    }

    static func codexError(_ diagnostic: String, exitStatus: Int32) -> MCPError {
        let text = diagnostic.lowercased()
        if text.contains("at capacity") || text.contains("overloaded") {
            return .io("Le modèle Codex est saturé. Réessaie dans quelques instants.")
        }
        if text.contains("model_not_found") || (text.contains("model") && text.contains("not supported")) {
            return .io("Le modèle demandé est indisponible avec ce compte Codex. Vérifie le modèle dans l’app Codex.")
        }
        if text.contains("usage_limit") || text.contains("usage limit") || text.contains("insufficient_quota") {
            return .io("La limite d’utilisation de Codex est atteinte. Vérifie sa date de renouvellement dans Codex.")
        }
        if text.contains("rate limit") || text.contains("rate_limit") {
            return .io("Codex reçoit trop de requêtes. Réessaie dans quelques instants.")
        }
        if text.contains("context_length_exceeded") || text.contains("context window") {
            return .io("Le fil dépasse la capacité du modèle. Ouvre-le dans Codex pour raccourcir son contexte.")
        }
        if text.contains("session not found") || text.contains("no conversation found") || text.contains("no rollout found") || text.contains("thread not found") {
            return .notFound("Codex ne retrouve pas la conversation d’origine sur ce Mac.")
        }
        if text.contains("401 unauthorized") || text.contains("invalid_api_key") || text.contains("not logged in") || text.contains("refresh token") {
            return .io("Codex demande une nouvelle connexion. Reconnecte ton compte Codex sur le Mac, puis réessaie.")
        }
        if text.contains("error sending request") || text.contains("connection failed") || text.contains("stream disconnected") {
            return .io("La connexion à Codex a été interrompue. Vérifie le réseau du Mac, puis réessaie.")
        }
        let code = exitStatus == 0 ? "" : " (code \(exitStatus))"
        return .io("Codex n’a pas terminé la réponse" + code + ". Ouvre la conversation dans Codex pour voir son état.")
    }

    static func parse(_ bytes: Data, conversation: ReplyConversation, exitStatus: Int32 = 0, diagnostics: String = "") throws -> String {
        // Only retry the pre-turn ownership conflict. A turn that has already started must never be replayed.
        if conversation.provider == .codex, exitStatus != 0,
           diagnostics.localizedCaseInsensitiveContains("thread/resume"),
           diagnostics.localizedCaseInsensitiveContains("already has an active writer"),
           !bytes.split(separator: 10).contains(where: { line in
               let event = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any]
               return event?["type"] as? String == "turn.started"
           }) {
            throw MCPError.codexActiveWriter
        }
        if conversation.provider == .codex, let failure = codexTurnFailure(in: bytes, failedExit: exitStatus != 0) {
            throw codexError(failure, exitStatus: exitStatus)
        }
        guard exitStatus == 0 else {
            if conversation.provider == .codex { throw codexError(diagnostics, exitStatus: exitStatus) }
            let text = String(decoding: bytes, as: UTF8.self) + diagnostics
            if text.localizedCaseInsensitiveContains("no conversation found") || text.localizedCaseInsensitiveContains("session not found") {
                throw MCPError.notFound("The original conversation could not be found on this Mac.")
            }
            throw MCPError.io(conversation.provider.rawValue + " couldn’t finish the reply. Check the CLI’s sign-in and the original conversation.")
        }

        var returnedSession: UUID?
        var answer: String?
        switch conversation.provider {
        case .claude:
            let result = try JSONSerialization.jsonObject(with: bytes) as? [String: Any]
            returnedSession = (result?["session_id"] as? String).flatMap(UUID.init(uuidString:))
            if result?["is_error"] as? Bool == false, result?["subtype"] as? String == "success" {
                answer = result?["result"] as? String
            }
        case .codex:
            var lastMessage: String?
            for line in bytes.split(separator: 10) {
                guard let event = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else { continue }
                switch event["type"] as? String {
                case "thread.started": returnedSession = (event["thread_id"] as? String).flatMap(UUID.init(uuidString:))
                case "item.completed":
                    if let item = event["item"] as? [String: Any], item["type"] as? String == "agent_message",
                       let text = item["text"] as? String, !text.isEmpty { lastMessage = text }
                case "turn.completed": answer = lastMessage
                default: break
                }
            }
        }
        guard returnedSession == conversation.sessionID else { throw MCPError.io("The CLI did not confirm the original conversation.") }
        guard let answer, !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MCPError.io("The CLI returned no answer. Check the original conversation before retrying.")
        }
        return answer
    }
}
