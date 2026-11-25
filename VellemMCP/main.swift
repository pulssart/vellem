import Foundation

private let usage = """
Usage: vellem-mcp
       vellem-mcp send [--agent NAME] [--title SUBJECT] [--format markdown|text|json|code] [--folder NAME] [--session-id UUID]
Without arguments, Vellem serves MCP over stdio. The send command reads one UTF-8 message from stdin.
"""

func send(_ options: ArraySlice<String>) throws {
    var args: [String: Any] = [:]
    let keys = ["--agent": "source_agent", "--title": "title", "--format": "format", "--folder": "folder_name", "--session-id": "session_id"]
    var iterator = options.makeIterator()
    while let flag = iterator.next() {
        guard let key = keys[flag], let value = iterator.next(), args[key] == nil else {
            throw MCPError.invalidArguments(usage)
        }
        args[key] = value
    }
    guard let text = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) else {
        throw MCPError.invalidArguments("Input must be UTF-8 text.")
    }
    args["text"] = text
    print(try MCPServer().deliverFromCLI(args))
}

let arguments = CommandLine.arguments.dropFirst()
switch arguments.first {
case nil: MCPServer().run()
case "--help", "-h": print(usage)
case "send":
    do {
        try send(arguments.dropFirst())
    } catch {
        FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
        exit(1)
    }
default:
    FileHandle.standardError.write(Data((usage + "\n").utf8))
    exit(2)
}
