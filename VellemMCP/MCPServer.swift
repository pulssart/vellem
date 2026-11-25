import Foundation

/// Minimal MCP server speaking JSON-RPC 2.0 over stdio.
/// Implements: initialize, tools/list, tools/call, ping.
final class MCPServer {
    private let store = NotesFileStore()
    private lazy var semantic = SemanticIndex()
    private let protocolVersion = "2024-11-05"
    private let serverName = "vellem"
    private let serverVersion = "1.0.0"

    // Shared formatter — ISO8601DateFormatter is expensive to instantiate.
    // nonisolated(unsafe) is safe here: the formatter is read-only after init.
    private nonisolated(unsafe) static let iso8601: ISO8601DateFormatter = ISO8601DateFormatter()

    func run() {
        FileHandle.standardError.write("vellem-mcp listening on stdio\n".data(using: .utf8)!)
        while let line = readLine(strippingNewline: true) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            handle(line: trimmed)
        }
    }

    // MARK: - Dispatch

    private func handle(line: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            sendError(id: nil, code: -32700, message: "Parse error")
            return
        }

        let id = json["id"]
        let method = json["method"] as? String
        let params = json["params"] as? [String: Any] ?? [:]

        switch method {
        case "initialize":
            handleInitialize(id: id, params: params)
        case "tools/list":
            handleToolsList(id: id)
        case "tools/call":
            handleToolCall(id: id, params: params)
        case "ping":
            send(id: id, result: [:])
        case let m? where m.hasPrefix("notifications/"):
            // Notifications expect no response.
            return
        case nil:
            // Response to a server-initiated request, ignore.
            return
        default:
            sendError(id: id, code: -32601, message: "Method not found: \(method ?? "nil")")
        }
    }

    // MARK: - Initialize

    private func handleInitialize(id: Any?, params: [String: Any]) {
        let clientInfo = params["clientInfo"] as? [String: Any]
        store.clientName = (clientInfo?["title"] as? String) ?? (clientInfo?["name"] as? String)
        store.clientAgent = InboxAgent.identify(clientInfo?["name"] as? String) ?? InboxAgent.identify(clientInfo?["title"] as? String)
        let result: [String: Any] = [
            "protocolVersion": protocolVersion,
            "instructions": "Vellem is a local inbox. Use send_output when the user asks to deliver text to Vellem. Send the complete original content and its format.",
            "capabilities": [
                "tools": [:] as [String: Any]
            ],
            "serverInfo": [
                "name": serverName,
                "version": serverVersion
            ]
        ]
        send(id: id, result: result)
    }

    // MARK: - Tools list

    private func handleToolsList(id: Any?) {
        let deliveryFields: [String: Any] = [
            "text": ["type": "string", "description": "Complete UTF-8 output. Preserve line breaks and indentation."],
            "format": ["type": "string", "enum": OutputFormat.allCases.map(\.rawValue), "description": "Use markdown for reports, tables, static HTML or LaTeX. Use text for literal prose, json for JSON data, and code for source files. Defaults to markdown."],
            "source_agent": ["type": "string", "description": "Sender name, for example Codex, Claude, Gemini, Grok or Grokbot. Defaults to the connected client."],
            "title": ["type": "string", "description": "Brief subject. Defaults to the first line."],
            "folder_id": ["type": "string", "description": "Destination folder UUID."],
            "folder_name": ["type": "string", "description": "Destination folder in the sender’s mailbox. Created if needed."]
        ]
        let tools: [[String: Any]] = [
            tool("send_output", description: "Deliver a report, project, code snippet or other text to the user's Vellem inbox on request.", properties: deliveryFields, required: ["text"]),
            tool("add_note", description: "Save text to Vellem. Compatible alias for send_output.", properties: deliveryFields, required: ["text"]),
            tool(
                "create_todo_list",
                description: "Create a Vellem note formatted as a to-do list.",
                properties: [
                    "source_agent": ["type": "string", "enum": InboxAgent.allCases.map(\.rawValue), "description": "Originating agent, if different from the MCP client or when using a generic bridge."],
                    "title": ["type": "string", "description": "Todo list title."],
                    "tasks": [
                        "type": "array",
                        "description": "Tasks to add. Each item can be a string, or an object with text and checked.",
                        "items": [
                            "oneOf": [
                                ["type": "string"],
                                [
                                    "type": "object",
                                    "properties": [
                                        "text": ["type": "string"],
                                        "checked": ["type": "boolean"]
                                    ],
                                    "required": ["text"]
                                ]
                            ]
                        ]
                    ],
                    "folder_id": ["type": "string", "description": "Optional folder UUID to place the note in."],
                    "folder_name": ["type": "string", "description": "Optional folder name. If it doesn't exist, it will be created."],
                ],
                required: ["title", "tasks"]
            ),
            tool(
                "list_notes",
                description: "List notes (most recent first). Returns id, title, preview, kind, updatedAt.",
                properties: [
                    "limit": ["type": "integer", "description": "Maximum number of notes to return. Default 20.", "minimum": 1, "maximum": 200]
                ],
                required: []
            ),
            tool(
                "search_notes",
                description: "Search notes by query. Matches title and body, case-insensitive (literal substring match). For meaning-based search use `search_notes_semantic`.",
                properties: [
                    "query": ["type": "string", "description": "Search string."],
                    "limit": ["type": "integer", "description": "Maximum results. Default 20.", "minimum": 1, "maximum": 200]
                ],
                required: ["query"]
            ),
            tool(
                "search_notes_semantic",
                description: "Search notes by meaning using Apple's on-device NLEmbedding plus a light title/body keyword signal. Returns notes ranked by a hybrid relevance score. Use this when the user asks in their own words rather than with exact keywords. The first call builds the embedding cache (one-shot ~seconds for large collections); subsequent calls are fast.",
                properties: [
                    "query": ["type": "string", "description": "Natural-language query, e.g. \"how to onboard a new teammate\"."],
                    "limit": ["type": "integer", "description": "Maximum results. Default 10.", "minimum": 1, "maximum": 50],
                    "min_score": ["type": "number", "description": "Optional similarity floor in [0,1]. Notes scoring below are dropped. Default 0.2."]
                ],
                required: ["query"]
            ),
            tool(
                "get_related_notes",
                description: "Given a note id, return the most semantically similar OTHER notes from the collection. Uses the same NLEmbedding pipeline as `search_notes_semantic`.",
                properties: [
                    "id": ["type": "string", "description": "Source note UUID."],
                    "limit": ["type": "integer", "description": "Maximum results. Default 5.", "minimum": 1, "maximum": 50],
                    "min_score": ["type": "number", "description": "Optional similarity floor in [0,1]. Default 0.3."]
                ],
                required: ["id"]
            ),
            tool(
                "list_recent_notes",
                description: "List notes updated within the last N days, most recent first. Use this when the user says \"this week\", \"recent\", \"lately\", etc. For an unbounded list use `list_notes`.",
                properties: [
                    "days": ["type": "integer", "description": "Window in days. 0 = today only, 1 = today + yesterday, 7 = last week, etc. Default 7.", "minimum": 0, "maximum": 365],
                    "limit": ["type": "integer", "description": "Maximum results. Default 50.", "minimum": 1, "maximum": 200]
                ],
                required: []
            ),
            tool(
                "get_daily_log",
                description: "Read an existing daily note for today, if present.",
                properties: [:],
                required: []
            ),
            tool(
                "get_note",
                description: "Get a note's full content by id.",
                properties: [
                    "id": ["type": "string", "description": "Note UUID."]
                ],
                required: ["id"]
            ),
            tool(
                "delete_note",
                description: "Delete a note by id.",
                properties: [
                    "id": ["type": "string"]
                ],
                required: ["id"]
            ),
            tool(
                "list_folders",
                description: "List all folders. Returns id, name, createdAt, and the number of notes in each.",
                properties: [:],
                required: []
            ),
            tool(
                "create_folder",
                description: "Create a folder. If a folder with the same name already exists, returns that one.",
                properties: [
                    "name": ["type": "string", "description": "Folder name."]
                ],
                required: ["name"]
            ),
            tool(
                "delete_folder",
                description: "Delete a folder by id. Notes inside are kept and moved to the root (no folder).",
                properties: [
                    "id": ["type": "string", "description": "Folder UUID."]
                ],
                required: ["id"]
            ),
            tool(
                "set_folder_color",
                description: "Set or clear a folder’s color metadata for legacy clients. Vellem for Mac shows all folders in grayscale. Accepted values: yellow, orange, red, pink, purple, blue, teal, green, gray, or null/empty to reset.",
                properties: [
                    "id": ["type": "string", "description": "Folder UUID."],
                    "color": ["type": "string", "description": "Color name, or empty to clear."]
                ],
                required: ["id"]
            ),
            tool(
                "move_note",
                description: "Move a note into a folder, or out of any folder. Provide either `folder_id`, `folder_name`, or none (to remove from its folder).",
                properties: [
                    "id": ["type": "string", "description": "Note UUID."],
                    "folder_id": ["type": "string", "description": "Target folder UUID."],
                    "folder_name": ["type": "string", "description": "Target folder name (created if missing)."]
                ],
                required: ["id"]
            )
        ]
        send(id: id, result: ["tools": tools])
    }

    private func tool(_ name: String, description: String, properties: [String: Any], required: [String]) -> [String: Any] {
        let schema: [String: Any] = [
            "type": "object",
            "properties": properties,
            "required": required
        ]
        return [
            "name": name,
            "description": description,
            "inputSchema": schema
        ]
    }

    // MARK: - Tool calls

    private func handleToolCall(id: Any?, params: [String: Any]) {
        let name = params["name"] as? String ?? ""
        let args = params["arguments"] as? [String: Any] ?? [:]

        do {
            let mutations: Set<String> = ["add_note", "send_output", "create_todo_list", "delete_note", "create_folder", "delete_folder", "set_folder_color", "move_note"]
            let text: String
            if mutations.contains(name) {
                text = try LibraryWriteLock.withLock(in: store.libraryDirectory) {
                    try execute(toolName: name, args: args, metadata: params["_meta"] as? [String: Any] ?? [:])
                }
            } else {
                text = try execute(toolName: name, args: args, metadata: params["_meta"] as? [String: Any] ?? [:])
            }
            send(id: id, result: [
                "content": [["type": "text", "text": text]],
                "isError": false
            ])
        } catch {
            send(id: id, result: [
                "content": [["type": "text", "text": "Error: \(error.localizedDescription)"]],
                "isError": true
            ])
        }
    }

    private func sourceAgent(from args: [String: Any]) throws -> InboxAgent? {
        guard let value = args["source_agent"] else { return nil }
        guard let name = value as? String, let agent = InboxAgent.identify(name) else {
            throw MCPError.invalidArguments("Choose a supported source_agent or omit it.")
        }
        return agent
    }

    private func replyConversation(agent: InboxAgent?, args: [String: Any], metadata: [String: Any]) throws -> ReplyConversation? {
        // A label or destination folder alone cannot identify a conversation.
        guard store.isDirectDelivery || store.clientAgent == agent else { return nil }
        let env = ProcessInfo.processInfo.environment
        let provider: ReplyConversation.Provider
        let session: String?
        switch agent {
        case .codex:
            provider = .codex
            session = metadata["threadId"] as? String ?? (store.isDirectDelivery ? env["CODEX_THREAD_ID"] : nil)
        case .claude:
            provider = .claude
            session = env["CLAUDE_CODE_SESSION_ID"]
        default: return nil
        }
        let explicit = store.isDirectDelivery ? args["session_id"] as? String : nil
        if let explicit, UUID(uuidString: explicit) == nil {
            throw MCPError.invalidArguments("Provide the originating CLI session UUID.")
        }
        guard let id = (explicit ?? session).flatMap(UUID.init(uuidString:)) else { return nil }
        let directory = provider == .claude ? env["CLAUDE_PROJECT_DIR"] : nil
        return ReplyConversation(provider: provider, sessionID: id,
                                 directory: directory ?? FileManager.default.currentDirectoryPath)
    }

    func deliverFromCLI(_ arguments: [String: Any]) throws -> String {
        store.isDirectDelivery = true
        return try LibraryWriteLock.withLock(in: store.libraryDirectory) {
            try execute(toolName: "send_output", args: arguments)
        }
    }

    private func execute(toolName: String, args: [String: Any], metadata: [String: Any] = [:]) throws -> String {
        switch toolName {
        case "send_output", "add_note":
            guard let text = args["text"] as? String,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw MCPError.invalidArguments("Provide a non-empty text body.")
            }
            let rawFormat = args["format"] ?? "markdown"
            guard let value = rawFormat as? String, let format = OutputFormat(rawValue: value) else {
                throw MCPError.invalidArguments("Choose markdown, text, json or code.")
            }
            let sender = (args["source_agent"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if args["source_agent"] != nil && sender?.isEmpty != false {
                throw MCPError.invalidArguments("Provide a sender name or omit source_agent.")
            }
            let agent = sender == nil ? store.clientAgent : InboxAgent.identify(sender)
            let folderID = try resolveFolderArg(args, agent: agent, sender: sender)
            let title = (args["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let note = try store.addNote(text: text, generatedTitle: title?.isEmpty == false ? title : nil,
                                         folderID: folderID, agent: agent, sender: sender, format: format,
                                         conversation: try replyConversation(agent: agent, args: args, metadata: metadata))
            return formatNoteCreated(note)

        case "create_todo_list":
            guard let title = (args["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty else {
                throw MCPError.invalidArguments("`title` is required.")
            }
            let tasks = try parseTodoItems(args["tasks"])
            guard !tasks.isEmpty else {
                throw MCPError.invalidArguments("`tasks` must include at least one task.")
            }
            let agent = try sourceAgent(from: args)
            let folderID = try resolveFolderArg(args, agent: agent)
            let text = todoListMarkdown(title: title, tasks: tasks)
            let note = try store.addNote(
                text: text,
                generatedTitle: title,
                folderID: folderID,
                agent: agent,
                conversation: try replyConversation(agent: agent ?? store.clientAgent, args: args, metadata: metadata)
            )
            return formatNoteCreated(note)

        case "list_notes":
            let limit = (args["limit"] as? Int) ?? 20
            let notes = try store.listNotes(limit: limit)
            return formatList(notes)

        case "search_notes":
            guard let query = (args["query"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !query.isEmpty else {
                throw MCPError.invalidArguments("`query` is required.")
            }
            let limit = (args["limit"] as? Int) ?? 20
            let notes = try store.searchNotes(query: query, limit: limit)
            if notes.isEmpty { return "No notes match \"\(query)\"." }
            return formatList(notes)

        case "search_notes_semantic":
            guard let query = (args["query"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !query.isEmpty else {
                throw MCPError.invalidArguments("`query` is required.")
            }
            let limit = (args["limit"] as? Int) ?? 10
            let minScore = parseNumber(args["min_score"]) ?? 0.2
            let allNotes = try store.allNotes()
            semantic.pruneMissing(keeping: Set(allNotes.map(\.id)))
            let matches = semantic.topMatches(forQuery: query, in: allNotes, limit: limit)
                .filter { $0.score >= minScore }
            if matches.isEmpty {
                return "No notes match \"\(query)\" semantically (min_score \(format(minScore))). The collection is \(allNotes.count) notes."
            }
            return formatScoredList(matches)

        case "get_related_notes":
            guard let idString = args["id"] as? String,
                  let uuid = UUID(uuidString: idString) else {
                throw MCPError.invalidArguments("`id` must be a valid UUID.")
            }
            guard try store.getNote(id: uuid) != nil else {
                throw MCPError.notFound("Note \(idString) not found.")
            }
            let limit = (args["limit"] as? Int) ?? 5
            let minScore = parseNumber(args["min_score"]) ?? 0.3
            let allNotes = try store.allNotes()
            semantic.pruneMissing(keeping: Set(allNotes.map(\.id)))
            let matches = semantic.topMatches(forNoteID: uuid, in: allNotes, limit: limit)
                .filter { $0.score >= minScore }
            if matches.isEmpty {
                return "No related notes found above score \(format(minScore)). The collection is \(allNotes.count) notes."
            }
            return formatScoredList(matches)

        case "list_recent_notes":
            let days = (args["days"] as? Int) ?? 7
            let limit = (args["limit"] as? Int) ?? 50
            let notes = try store.recentNotes(days: days, limit: limit)
            if notes.isEmpty {
                return "No notes updated in the last \(days) day\(days == 1 ? "" : "s")."
            }
            return formatList(notes)

        case "get_daily_log":
            guard let note = try store.dailyNote(for: Date()) else {
                return "status: missing\nNo daily note exists for today."
            }
            return formatFullNote(note)

        case "get_note":
            guard let idString = args["id"] as? String,
                  let uuid = UUID(uuidString: idString) else {
                throw MCPError.invalidArguments("`id` must be a valid UUID.")
            }
            guard let note = try store.getNote(id: uuid) else {
                throw MCPError.notFound("Note \(idString) not found.")
            }
            return formatFullNote(note)

        case "delete_note":
            guard let idString = args["id"] as? String,
                  let uuid = UUID(uuidString: idString) else {
                throw MCPError.invalidArguments("`id` must be a valid UUID.")
            }
            try store.deleteNote(id: uuid)
            return "Deleted note \(idString)."

        case "list_folders":
            let folders = try store.listFolders()
            if folders.isEmpty { return "No folders." }
            let notes = try store.listNotes(limit: 10_000)
            let f = ISO8601DateFormatter()
            return folders.map { folder in
                let count = notes.filter { noteMatchesFolderDisplay($0, folder: folder) }.count
                return "\(folder.id)  \(folder.displayPath)  (\(count) notes, created \(f.string(from: folder.createdAt)))"
            }.joined(separator: "\n")

        case "create_folder":
            guard let name = (args["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else {
                throw MCPError.invalidArguments("`name` is required.")
            }
            let folder = try store.createFolder(name: name)
            return "Folder ready.\nid: \(folder.id)\nname: \(folder.name)"

        case "delete_folder":
            guard let idString = args["id"] as? String,
                  let uuid = UUID(uuidString: idString) else {
                throw MCPError.invalidArguments("`id` must be a valid UUID.")
            }
            try store.deleteFolder(id: uuid)
            return "Deleted folder \(idString). Its notes were moved to the root."

        case "set_folder_color":
            guard let idString = args["id"] as? String,
                  let uuid = UUID(uuidString: idString) else {
                throw MCPError.invalidArguments("`id` must be a valid UUID.")
            }
            let allowed: Set<String> = ["yellow","orange","red","pink","purple","blue","teal","green","gray"]
            let raw = (args["color"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            let value: String?
            if raw.isEmpty {
                value = nil
            } else if allowed.contains(raw) {
                value = raw
            } else {
                throw MCPError.invalidArguments("`color` must be one of \(allowed.sorted().joined(separator: ", ")) or empty.")
            }
            let folder = try store.setFolderColor(id: uuid, color: value)
            return "Folder \(folder.id) color set to \(folder.color ?? "default")."

        case "move_note":
            guard let idString = args["id"] as? String,
                  let uuid = UUID(uuidString: idString) else {
                throw MCPError.invalidArguments("`id` must be a valid UUID.")
            }
            let folderID = try resolveFolderArg(args)
            let note = try store.moveNote(id: uuid, toFolder: folderID)
            let folderLabel: String
            if let folderID,
               let folder = try store.listFolders().first(where: { $0.id == folderID }) {
                folderLabel = "into folder \"\(folder.name)\" (\(folder.id))"
            } else {
                folderLabel = "to the root (no folder)"
            }
            return "Moved note \(note.id) \(folderLabel)."

        default:
            throw MCPError.unknownTool(toolName)
        }
    }

    // MARK: - Folder resolution

    private func resolveFolderArg(_ args: [String: Any], agent: InboxAgent? = nil, sender: String? = nil) throws -> UUID? {
        if let idString = (args["folder_id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !idString.isEmpty {
            guard let uuid = UUID(uuidString: idString) else {
                throw MCPError.invalidArguments("`folder_id` must be a valid UUID.")
            }
            return uuid
        }
        if let name = (args["folder_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            let folder = try store.createFolder(name: name, agent: agent, sender: sender)
            return folder.id
        }
        return nil
    }

    // MARK: - Formatting helpers

    private func formatNoteCreated(_ note: Note) -> String {
        return """
        Created note.
        id: \(note.id)
        title: \(note.title)
        words: \(note.wordCount)
        updatedAt: \(Self.iso8601.string(from: note.updatedAt))
        """
    }

    private func formatList(_ notes: [Note]) -> String {
        guard !notes.isEmpty else { return "No notes." }
        return notes.map { n in
            let kindLabel = n.isDailyNote ? "[daily] " : ""
            return "\(n.id)  \(kindLabel)\(n.title)  (\(n.wordCount)w, updated \(Self.iso8601.string(from: n.updatedAt)))\n  \(n.preview.prefix(120))"
        }.joined(separator: "\n\n")
    }

    private func formatScoredList(_ matches: [(note: Note, score: Double)]) -> String {
        guard !matches.isEmpty else { return "No matches." }
        return matches.map { match in
            let n = match.note
            let kindLabel = n.isDailyNote ? "[daily] " : ""
            return "\(n.id)  score=\(format(match.score))  \(kindLabel)\(n.title)  (\(n.wordCount)w, updated \(Self.iso8601.string(from: n.updatedAt)))\n  \(n.preview.prefix(120))"
        }.joined(separator: "\n\n")
    }

    private func format(_ score: Double) -> String {
        String(format: "%.3f", score)
    }

    /// JSON-RPC numeric args arrive as either Int or Double depending on the
    /// client — normalize both into Double.
    private func parseNumber(_ raw: Any?) -> Double? {
        if let d = raw as? Double { return d }
        if let i = raw as? Int { return Double(i) }
        if let s = raw as? String, let d = Double(s) { return d }
        return nil
    }

    private func formatFullNote(_ note: Note) -> String {
        var meta = "id: \(note.id)\ntitle: \(note.title)\nkind: \(note.isDailyNote ? "daily" : "regular")\nupdatedAt: \(Self.iso8601.string(from: note.updatedAt))\n"
        if let format = note.outputFormat { meta += "format: \(format.rawValue)\n" }
        if let src = note.sourceApp { meta += "sourceApp: \(src)\n" }
        if let url = note.sourceURL { meta += "sourceURL: \(url.absoluteString)\n" }
        if let folderID = note.folderID {
            let folderName = (try? store.listFolders().first { $0.id == folderID })?.name
            meta += "folder: \(folderName ?? "<missing>") (\(folderID))\n"
        }
        return meta + "\n---\n\n" + note.text
    }

    private func noteMatchesFolderDisplay(_ note: Note, folder: Folder) -> Bool {
        if folder.kind == .regular { return note.folderID == folder.id }
        guard !note.isDailyNote else { return false }

        switch folder.kind {
        case .smartClaude:
            return note.folderID == folder.id || note.isFromClaude
        case .smartCodex:
            return note.folderID == folder.id || note.isFromCodex
        case .smartPromptLibrary:
            return false
        case .smartServices, .regular:
            return note.folderID == folder.id
        }
    }

    private func parseTodoItems(_ value: Any?) throws -> [(text: String, checked: Bool)] {
        guard let rawItems = value as? [Any] else {
            throw MCPError.invalidArguments("`tasks` must be an array.")
        }

        return rawItems.compactMap { item in
            if let text = item as? String {
                let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                return cleaned.isEmpty ? nil : (cleaned, false)
            }

            if let object = item as? [String: Any],
               let text = object["text"] as? String {
                let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else { return nil }
                return (cleaned, (object["checked"] as? Bool) ?? false)
            }

            return nil
        }
    }

    private func todoListMarkdown(title: String, tasks: [(text: String, checked: Bool)]) -> String {
        let rows = tasks.map { task in
            todoLine(text: task.text, checked: task.checked)
        }
        return "# \(title)\n\n" + rows.joined(separator: "\n")
    }

    private func todoLine(text: String, checked: Bool) -> String {
        "- [\(checked ? "x" : " ")] \(text)"
    }

    // MARK: - JSON-RPC framing (newline-delimited)

    private func send(id: Any?, result: Any) {
        var envelope: [String: Any] = [
            "jsonrpc": "2.0",
            "result": result
        ]
        if let id { envelope["id"] = id }
        write(envelope)
    }

    private func sendError(id: Any?, code: Int, message: String) {
        var envelope: [String: Any] = [
            "jsonrpc": "2.0",
            "error": ["code": code, "message": message]
        ]
        if let id { envelope["id"] = id } else { envelope["id"] = NSNull() }
        write(envelope)
    }

    private func write(_ envelope: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: envelope, options: []) else { return }
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write("\n".data(using: .utf8)!)
    }
}
