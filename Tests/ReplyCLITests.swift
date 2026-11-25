import Foundation

// swiftc -enable-bare-slash-regex Tests/ReplyCLITests.swift VellemReplies/ReplyCLI.swift VellemMCP/MCPError.swift Vellem/Models/Note.swift VellemShared/VellemDisplayText.swift VellemShared/VellemLanguage.swift -o /tmp/vellem-reply-tests
@main
enum ReplyCLITests {
    static func main() throws {
        let chat = ReplyConversation(provider: .codex, sessionID: UUID(), directory: "/tmp")
        let start = #"{"type":"thread.started","thread_id":"\#(chat.sessionID)"}"#
        let output = #"{"type":"item.completed","item":{"type":"agent_message","text":"Bonjour"}}"#
        let capacity = #"{"type":"turn.failed","error":{"message":"Selected model is at capacity. Please try a different model."}}"#
        let retry = #"{"type":"error","message":"Reconnecting... stream disconnected"}"#
        let complete = #"{"type":"turn.completed"}"#

        func parse(_ lines: [String], status: Int32, stderr: String = "") throws -> String {
            try ReplyCLI.parse(Data(lines.joined(separator: "\n").utf8), conversation: chat, exitStatus: status, diagnostics: stderr)
        }
        func expectFailure(_ lines: [String], status: Int32, stderr: String = "", containing text: String) {
            do {
                _ = try parse(lines, status: status, stderr: stderr)
                fatalError("The CLI failure was treated as a successful reply")
            } catch {
                precondition(error.localizedDescription.contains(text), error.localizedDescription)
            }
        }
        expectFailure([], status: 1, stderr: "Error: thread/resume: thread 0123 already has an active writer (code -32600)", containing: "ouverte dans Codex")
        expectFailure([start, #"{"type":"turn.started"}"#], status: 1,
                      stderr: "thread/resume: thread 0123 already has an active writer", containing: "code 1")
        expectFailure([start, retry, capacity], status: 1, stderr: "401 Unauthorized from an unrelated MCP", containing: "saturé")
        expectFailure([retry], status: 1, containing: "interrompue")
        expectFailure([], status: 1, stderr: "401 Unauthorized", containing: "connexion")
        expectFailure([output, complete], status: 0, containing: "original conversation")
        let answer = try parse([start, retry, output, complete], status: 0, stderr: "unrelated tool failed")
        precondition(answer == "Bonjour")
    }
}
