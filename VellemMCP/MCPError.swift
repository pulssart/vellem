import Foundation

enum MCPError: LocalizedError {
    case invalidArguments(String)
    case notFound(String)
    case codexActiveWriter
    case unknownTool(String)
    case io(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let msg): return msg
        case .notFound(let msg): return msg
        case .codexActiveWriter: return "Cette conversation est déjà ouverte dans Codex."
        case .unknownTool(let name): return "Unknown tool: \(name)"
        case .io(let msg): return msg
        }
    }
}
