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
        let result: [String: Any] = [
            "protocolVersion": protocolVersion,
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
        let tools: [[String: Any]] = [
            tool(
                "add_note",
                description: "Create a new note in Vellem. Use Markdown for formatting (headings with #, todos with `- [ ] item`, bullets with `- `, etc.). Optionally place it in a folder by UUID or by name (auto-created if unknown).",
                properties: [
                    "text": ["type": "string", "description": "Markdown body of the note."],
                    "title": ["type": "string", "description": "Optional explicit title. If omitted, the first line or first heading is used."],
                    "folder_id": ["type": "string", "description": "Optional folder UUID to place the note in."],
                    "folder_name": ["type": "string", "description": "Optional folder name. If it doesn't exist, it will be created."]
                ],
                required: ["text"]
            ),
            tool(
                "append_to_daily",
                description: "Append a snippet to today's daily note, creating it if needed.",
                properties: [
                    "text": ["type": "string", "description": "Markdown text to append."]
                ],
                required: ["text"]
            ),
            tool(
                "create_todo_list",
                description: "Create a Vellem note formatted as a to-do list. Tasks are written as Markdown checkboxes that Vellem renders as interactive todos.",
                properties: [
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
                    "folder_name": ["type": "string", "description": "Optional folder name. If it doesn't exist, it will be created."]
                ],
                required: ["title", "tasks"]
            ),
            tool(
                "add_todo",
                description: "Append one task to an existing Vellem note as a Markdown checkbox.",
                properties: [
                    "id": ["type": "string", "description": "Target note UUID."],
                    "text": ["type": "string", "description": "Task text."],
                    "checked": ["type": "boolean", "description": "Whether the task starts completed. Default false."]
                ],
                required: ["id", "text"]
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
                description: "Search notes by semantic meaning using Apple's on-device NLEmbedding (French & English supported). Returns notes ranked by cosine similarity to the query. Use this when the user asks in their own words rather than with exact keywords. The first call builds the embedding cache (one-shot ~seconds for large collections); subsequent calls are fast.",
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
                description: "Return today's daily note (the one written by `append_to_daily`). Returns null content with status `missing` if no daily note exists yet.",
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
                "update_note",
                description: "Modify a note's body by id. Supports three modes: `replace` (default) overwrites the whole body, `append` adds the new text at the end, `prepend` inserts it at the start. The `title` argument is only honored in replace mode; in append/prepend the title is re-derived from the resulting first heading or first line.",
                properties: [
                    "id": ["type": "string"],
                    "text": ["type": "string", "description": "Markdown text to apply."],
                    "title": ["type": "string", "description": "Optional explicit title (replace mode only). If omitted, derived from the first heading / first line of the new text."],
                    "mode": ["type": "string", "description": "How to apply `text`. One of `replace`, `append`, `prepend`. Default `replace`.", "enum": ["replace", "append", "prepend"]]
                ],
                required: ["id", "text"]
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
                description: "Set or clear a folder's color. Accepted values: yellow, orange, red, pink, purple, blue, teal, green, gray, or null/empty to reset.",
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
        return [
            "name": name,
            "description": description,
            "inputSchema": [
                "type": "object",
                "properties": properties,
                "required": required
            ]
        ]
    }

    // MARK: - Tool calls

    private func handleToolCall(id: Any?, params: [String: Any]) {
        let name = params["name"] as? String ?? ""
        let args = params["arguments"] as? [String: Any] ?? [:]

        do {
            let text = try execute(toolName: name, args: args)
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

    private func execute(toolName: String, args: [String: Any]) throws -> String {
        switch toolName {
        case "add_note":
            guard let text = (args["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                throw MCPError.invalidArguments("`text` is required and cannot be empty.")
            }
            let title = (args["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let folderID = try resolveFolderArg(args)
            let note = try store.addNote(
                text: text,
                generatedTitle: title?.isEmpty == false ? title : nil,
                folderID: folderID
            )
            return formatNoteCreated(note)

        case "append_to_daily":
            guard let text = (args["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                throw MCPError.invalidArguments("`text` is required.")
            }
            let note = try store.appendToDaily(text: text)
            return "Added to today's note (\(note.id)). New length: \(note.text.count) chars."

        case "create_todo_list":
            guard let title = (args["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty else {
                throw MCPError.invalidArguments("`title` is required.")
            }
            let tasks = try parseTodoItems(args["tasks"])
            guard !tasks.isEmpty else {
                throw MCPError.invalidArguments("`tasks` must include at least one task.")
            }
            let folderID = try resolveFolderArg(args)
            let text = todoListMarkdown(title: title, tasks: tasks)
            let note = try store.addNote(
                text: text,
                generatedTitle: title,
                folderID: folderID
            )
            return formatNoteCreated(note)

        case "add_todo":
            guard let idString = args["id"] as? String,
                  let uuid = UUID(uuidString: idString) else {
                throw MCPError.invalidArguments("`id` must be a valid UUID.")
            }
            guard let taskText = (args["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !taskText.isEmpty else {
                throw MCPError.invalidArguments("`text` is required.")
            }
            guard let note = try store.getNote(id: uuid) else {
                throw MCPError.notFound("Note \(idString) not found.")
            }
            let checked = (args["checked"] as? Bool) ?? false
            let updatedText = appendTodo(taskText, checked: checked, to: note.text)
            let updated = try store.updateNote(id: uuid, text: updatedText)
            return "Added todo to note \(updated.id). Title: \(updated.title)."

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
                return "status: missing\nNo daily note exists for today. Use `append_to_daily` to start one."
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

        case "update_note":
            guard let idString = args["id"] as? String,
                  let uuid = UUID(uuidString: idString) else {
                throw MCPError.invalidArguments("`id` must be a valid UUID.")
            }
            guard let text = args["text"] as? String else {
                throw MCPError.invalidArguments("`text` is required.")
            }
            let modeRaw = (args["mode"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? "replace"
            let note: Note
            switch modeRaw {
            case "", "replace":
                let titleArg = args["title"] as? String
                note = try store.updateNote(id: uuid, text: text, title: titleArg)
            case "append":
                note = try store.appendToNote(id: uuid, text: text)
            case "prepend":
                note = try store.prependToNote(id: uuid, text: text)
            default:
                throw MCPError.invalidArguments("`mode` must be one of replace, append, prepend.")
            }
            return "Updated note \(note.id) (\(modeRaw == "" ? "replace" : modeRaw)). Title: \(note.title). Words: \(note.wordCount)."

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
                return "\(folder.id)  \(folder.name)  (\(count) notes, created \(f.string(from: folder.createdAt)))"
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

    private func resolveFolderArg(_ args: [String: Any]) throws -> UUID? {
        if let idString = (args["folder_id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !idString.isEmpty {
            guard let uuid = UUID(uuidString: idString) else {
                throw MCPError.invalidArguments("`folder_id` must be a valid UUID.")
            }
            return uuid
        }
        if let name = (args["folder_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            let folder = try store.createFolder(name: name)
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
        if let src = note.sourceApp { meta += "sourceApp: \(src)\n" }
        if let url = note.sourceURL { meta += "sourceURL: \(url.absoluteString)\n" }
        if let folderID = note.folderID {
            let folderName = (try? store.listFolders().first { $0.id == folderID })?.name
            meta += "folder: \(folderName ?? "<missing>") (\(folderID))\n"
        }
        return meta + "\n---\n\n" + note.text
    }

    private func noteMatchesFolderDisplay(_ note: Note, folder: Folder) -> Bool {
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

    private func appendTodo(_ text: String, checked: Bool, to noteText: String) -> String {
        let cleanedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = cleanedNote.isEmpty ? "" : "\n"
        return cleanedNote + separator + todoLine(text: text, checked: checked)
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

enum MCPError: LocalizedError {
    case invalidArguments(String)
    case notFound(String)
    case unknownTool(String)
    case io(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let msg): return msg
        case .notFound(let msg): return msg
        case .unknownTool(let name): return "Unknown tool: \(name)"
        case .io(let msg): return msg
        }
    }
}
