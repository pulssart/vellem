import AppKit
import SwiftUI

struct FolderNotesListView: View {
    @ObservedObject var store: NotesStore
    let folder: Folder
    @Environment(\.openWindow) private var openWindow
    @State private var isDropping = false
    @State private var copiedIntegrationSetup = false
    @State private var copiedWorkflowID: AgentWorkflow.ID?
    @AppAccent private var accent

    private var notes: [Note] {
        store.notes.filter { $0.folderID == folder.id && !$0.isDailyNote }
    }

    private var workflows: [AgentWorkflow] {
        AgentWorkflow.workflows(for: folder)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if notes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        workflowCards

                        ForEach(notes) { note in
                            FolderNoteListRow(note: note, onOpenViewer: {
                                openInFloatingViewer(note)
                            }) {
                                select(note)
                            }
                            .contextMenu {
                                noteContextMenu(note)
                            }
                            .draggable(note.id.uuidString) {
                                FolderNoteListRow(note: note) {}
                                    .frame(width: 280)
                                    .padding(6)
                                    .background(Color(nsColor: .windowBackgroundColor))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle(folder.name)
        .background(Color(nsColor: .textBackgroundColor))
        .overlay {
            if isDropping {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(accent.color, lineWidth: 2)
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: String.self) { items, _ in
            handleDrop(items)
        } isTargeted: { hovering in
            isDropping = hovering
        }
    }

    @ViewBuilder
    private var workflowCards: some View {
        if !workflows.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Ready-to-use workflows")
                        .font(.headline)

                    Spacer()

                    Text("Copy a prompt, paste it into \(folder.name).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                    ForEach(workflows) { workflow in
                        AgentWorkflowCard(
                            workflow: workflow,
                            isCopied: copiedWorkflowID == workflow.id,
                            targetApp: folder.kind == .smartCodex ? .codex : .claude
                        ) {
                            copy(workflow.prompt)
                            copiedWorkflowID = workflow.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                if copiedWorkflowID == workflow.id {
                                    copiedWorkflowID = nil
                                }
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
            )
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: folder.systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(FolderColor.named(folder.color)?.swiftUIColor ?? accent.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)

                Text("\(notes.count) note\(notes.count > 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                createNoteInFolder()
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(.borderless)
            .help("New note in folder")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var emptyState: some View {
        Group {
            if let guide = IntegrationGuide(folder: folder) {
                integrationEmptyState(guide)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: folder.outlineSystemImage)
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(.tertiary)

                    Text("No notes in this folder")
                        .font(.headline)

                    Text("Drop notes here or create one from the top right.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private func integrationEmptyState(_ guide: IntegrationGuide) -> some View {
        VStack(spacing: 16) {
            Image(systemName: folder.outlineSystemImage)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(FolderColor.named(folder.color)?.swiftUIColor ?? accent.color)

            VStack(spacing: 5) {
                Text("Connect \(folder.name) to Vellem")
                    .font(.headline)

                Text("Add this MCP server config, then ask \(folder.name) to wire it for you.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(guide.config)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )

                Text("Prompt")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(guide.prompt)
                    .font(.caption)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    copy(guide.clipboardText)
                    copiedIntegrationSetup = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copiedIntegrationSetup = false
                    }
                } label: {
                    Label(copiedIntegrationSetup ? "Copied" : "Copy setup", systemImage: copiedIntegrationSetup ? "checkmark" : "doc.on.doc")
                }
                .controlSize(.small)
                .padding(.top, 4)
            }
            .frame(maxWidth: 560)

            workflowCards
                .frame(maxWidth: 720)
        }
    }

    @ViewBuilder
    private func noteContextMenu(_ note: Note) -> some View {
        Button("Open in floating window") {
            openInFloatingViewer(note)
        }
        Menu("Move to") {
            Button("No folder") {
                store.moveNote(note.id, toFolder: nil)
            }
            if !store.folders.isEmpty {
                Divider()
                ForEach(store.folders) { targetFolder in
                    Button(targetFolder.name) {
                        store.moveNote(note.id, toFolder: targetFolder.id)
                    }
                }
            }
        }
        Button("Copy") {
            copy(note.text)
        }
        Button(note.isRead ? "Mark as unread" : "Mark as read") {
            note.isRead ? store.markUnread(note.id) : store.markRead(note.id)
        }
        Button("Delete", role: .destructive) {
            store.delete(note)
            store.selectedNoteID = nil
        }
    }

    private func select(_ note: Note) {
        store.selectNote(note.id, inFolder: folder.id)
    }

    private func createNoteInFolder() {
        let note = store.createDraft()
        store.moveNote(note.id, toFolder: folder.id)
        select(note)
    }

    private func handleDrop(_ items: [String]) -> Bool {
        var moved = false
        for item in items {
            guard let uuid = UUID(uuidString: item) else { continue }
            store.moveNote(uuid, toFolder: folder.id)
            moved = true
        }
        return moved
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func openInFloatingViewer(_ note: Note) {
        store.viewerNoteID = note.id
        openWindow(id: "note-viewer")
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct IntegrationGuide {
    let config: String
    let prompt: String
    let clipboardText: String

    init?(folder: Folder) {
        switch folder.kind {
        case .smartClaude:
            config = """
            {
              "mcpServers": {
                "vellem": {
                  "command": "/Applications/Vellem.app/Contents/Resources/vellem-mcp"
                }
              }
            }
            """
            prompt = "Add this MCP server to Claude Desktop, restart Claude, then send notes and reports to Vellem with folder_name: \"Claude\"."
        case .smartCodex:
            config = """
            [mcp_servers.vellem]
            command = "/Applications/Vellem.app/Contents/Resources/vellem-mcp"
            """
            prompt = "Add this MCP server to Codex, then use it to send reports, analyses, diagnostics, and notes to Vellem with folder_name: \"Codex\"."
        default:
            return nil
        }
        clipboardText = """
        \(prompt)

        \(config)
        """
    }
}

private struct AgentWorkflow: Identifiable {
    let id: String
    let title: String
    let description: String
    let systemImage: String
    let prompt: String

    static func workflows(for folder: Folder) -> [AgentWorkflow] {
        switch folder.kind {
        case .smartClaude:
            return claudeWorkflows
        case .smartCodex:
            return codexWorkflows
        default:
            return []
        }
    }

    static let dailyLogWorkflows: [AgentWorkflow] = [
        AgentWorkflow(
            id: "today-slack-email",
            title: "Slack and email recap",
            description: "Summarize messages that matter today.",
            systemImage: "tray.and.arrow.down",
            prompt: """
            Review today's important Slack messages and email threads.
            Summarize decisions, blockers, requests, and follow-ups.
            Append the result to today's Vellem note with `append_to_daily`.
            Keep it short and useful for an end-of-day review.
            """
        ),
        AgentWorkflow(
            id: "today-calendar-granola",
            title: "Meetings recap",
            description: "Turn Calendar and Granola into a daily log.",
            systemImage: "calendar.badge.clock",
            prompt: """
            Review today's Calendar events and Granola meeting notes.
            Extract decisions, action items, people involved, and open questions.
            Append a clean meeting recap to today's Vellem note with `append_to_daily`.
            """
        ),
        AgentWorkflow(
            id: "today-linear-progress",
            title: "Linear progress",
            description: "Log issue movement and next actions.",
            systemImage: "list.bullet.rectangle",
            prompt: """
            Review today's Linear activity.
            Summarize issues moved, comments that need attention, blockers, and next actions.
            Append this project progress log to today's Vellem note with `append_to_daily`.
            """
        ),
        AgentWorkflow(
            id: "today-figma-design",
            title: "Figma design log",
            description: "Capture design changes and rationale.",
            systemImage: "square.on.square",
            prompt: """
            Review today's relevant Figma work.
            Summarize changed screens, design decisions, feedback, unresolved questions, and handoff notes.
            Append this design log to today's Vellem note with `append_to_daily`.
            """
        )
    ]

    private static let codexWorkflows: [AgentWorkflow] = [
        AgentWorkflow(
            id: "codex-save-audit",
            title: "Save audit to Codex",
            description: "Store a structured review in the Codex folder.",
            systemImage: "checkmark.seal",
            prompt: """
            When you finish a code audit, save the final report to Vellem using the `add_note` tool.
            Use `folder_name: "Codex"`.
            Title the note clearly.
            Include findings first, then risks, then concrete next steps.
            """
        ),
        AgentWorkflow(
            id: "codex-implementation-todos",
            title: "Create implementation todos",
            description: "Turn a plan into a Vellem checklist.",
            systemImage: "checklist",
            prompt: """
            Turn the implementation plan into a todo list in Vellem using `create_todo_list`.
            Use `folder_name: "Codex"`.
            Keep each task concrete, small, and verifiable.
            """
        ),
        AgentWorkflow(
            id: "codex-project-memory",
            title: "Search project memory",
            description: "Use older notes before making changes.",
            systemImage: "magnifyingglass",
            prompt: """
            Before changing the project, search Vellem with `search_notes` for relevant prior decisions, audits, and implementation notes.
            Prefer notes from the Codex folder.
            Summarize what matters before you edit files.
            """
        ),
        AgentWorkflow(
            id: "codex-daily-progress",
            title: "Append progress to today",
            description: "Keep the daily work log current.",
            systemImage: "calendar.badge.plus",
            prompt: """
            At the end of this task, append a short progress note to today's Vellem note with `append_to_daily`.
            Include what changed, what was verified, and what remains open.
            """
        ),
        AgentWorkflow(
            id: "codex-bug-repro",
            title: "Save bug reproduction",
            description: "Capture steps, expected result, and actual result.",
            systemImage: "ladybug",
            prompt: """
            When you identify a bug, save a reproduction note to Vellem using `add_note`.
            Use `folder_name: "Codex"`.
            Include steps to reproduce, expected result, actual result, likely cause, and files involved.
            """
        ),
        AgentWorkflow(
            id: "codex-pr-summary",
            title: "Save PR summary",
            description: "Keep a short technical summary after changes.",
            systemImage: "arrow.triangle.pull",
            prompt: """
            After finishing the implementation, save a PR-style summary to Vellem using `add_note`.
            Use `folder_name: "Codex"`.
            Include changed files, behavior changes, verification, and follow-up risks.
            """
        )
    ]

    private static let claudeWorkflows: [AgentWorkflow] = [
        AgentWorkflow(
            id: "claude-research-note",
            title: "Save research note",
            description: "Keep research output in the Claude folder.",
            systemImage: "doc.text.magnifyingglass",
            prompt: """
            When you finish the research, save a clear research note to Vellem using `add_note`.
            Use `folder_name: "Claude"`.
            Include the question, the answer, useful sources, and open questions.
            """
        ),
        AgentWorkflow(
            id: "claude-meeting-prep",
            title: "Append meeting prep",
            description: "Add prep notes to today's note.",
            systemImage: "person.2",
            prompt: """
            Prepare concise meeting notes, then append them to today's Vellem note with `append_to_daily`.
            Include context, goals, questions to ask, and decisions to confirm.
            """
        ),
        AgentWorkflow(
            id: "claude-action-list",
            title: "Create action list",
            description: "Turn discussion into tasks.",
            systemImage: "checklist",
            prompt: """
            Turn this discussion into a Vellem todo list with `create_todo_list`.
            Use `folder_name: "Claude"`.
            Each task should start with a verb and be easy to verify.
            """
        ),
        AgentWorkflow(
            id: "claude-memory-search",
            title: "Search memory first",
            description: "Recover previous notes before answering.",
            systemImage: "clock.arrow.circlepath",
            prompt: """
            Before answering, search Vellem with `search_notes` for related notes.
            Use the results as context, then mention which notes influenced the answer.
            """
        ),
        AgentWorkflow(
            id: "claude-decision-log",
            title: "Save decision log",
            description: "Record decisions with rationale.",
            systemImage: "checkmark.bubble",
            prompt: """
            When a decision is made, save it to Vellem using `add_note`.
            Use `folder_name: "Claude"`.
            Include the decision, context, rationale, alternatives considered, and next step.
            """
        ),
        AgentWorkflow(
            id: "claude-summarize-thread",
            title: "Summarize thread",
            description: "Turn a long exchange into a clean note.",
            systemImage: "text.alignleft",
            prompt: """
            Summarize this thread into a clean Vellem note using `add_note`.
            Use `folder_name: "Claude"`.
            Keep the summary practical: context, key points, decisions, tasks, and open questions.
            """
        )
    ]
}

private struct AgentWorkflowCard: View {
    let workflow: AgentWorkflow
    let isCopied: Bool
    let targetApp: AgentApp
    let onCopy: () -> Void
    @AppAccent private var accent
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: workflow.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accent.color)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text(workflow.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)

                    Text(workflow.description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Button(action: onCopy) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.borderless)
                .help(isCopied ? "Copied" : "Copy prompt")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovering ? accent.color.opacity(0.08) : Color(nsColor: .windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isHovering ? accent.color.opacity(0.55) : Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            AgentLauncher.send(prompt: workflow.prompt, to: targetApp)
        }
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .help("Open in \(targetApp.displayName) Desktop with this prompt")
    }
}

struct FolderNoteEditorContainer: View {
    @ObservedObject var store: NotesStore
    let folder: Folder
    let note: Note

    var body: some View {
        NoteEditorView(store: store, note: note)
    }
}

struct TodayNotesListView: View {
    @ObservedObject var store: NotesStore
    @Environment(\.openWindow) private var openWindow
    @State private var copiedWorkflowID: AgentWorkflow.ID?
    @AppAccent private var accent

    private var notes: [Note] {
        store.notes.filter { !$0.isDailyNote && Calendar.current.isDateInToday($0.createdAt) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if notes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        workflowCards

                        ForEach(notes) { note in
                            FolderNoteListRow(note: note, onOpenViewer: {
                                openInFloatingViewer(note)
                            }) {
                                store.selectNote(note.id, inToday: true)
                            }
                            .contextMenu {
                                noteContextMenu(note)
                            }
                            .draggable(note.id.uuidString) {
                                FolderNoteListRow(note: note) {}
                                    .frame(width: 280)
                                    .padding(6)
                                    .background(Color(nsColor: .windowBackgroundColor))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Today")
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(accent.color)

            VStack(alignment: .leading, spacing: 2) {
                Text("Today")
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)

                Text("\(notes.count) note\(notes.count > 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var workflowCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily log prompts")
                    .font(.headline)

                Spacer()

                Text("Copy a prompt, paste it into your agent.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                ForEach(AgentWorkflow.dailyLogWorkflows) { workflow in
                    AgentWorkflowCard(
                        workflow: workflow,
                        isCopied: copiedWorkflowID == workflow.id,
                        targetApp: .claude
                    ) {
                        copy(workflow.prompt)
                        copiedWorkflowID = workflow.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            if copiedWorkflowID == workflow.id {
                                copiedWorkflowID = nil
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(.tertiary)

                    Text("No notes today")
                        .font(.headline)

                    Text("Notes created today will appear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)

                workflowCards
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func noteContextMenu(_ note: Note) -> some View {
        Button("Open in floating window") {
            openInFloatingViewer(note)
        }
        Menu("Move to") {
            Button("No folder") {
                store.moveNote(note.id, toFolder: nil)
            }
            if !store.folders.isEmpty {
                Divider()
                ForEach(store.folders) { targetFolder in
                    Button(targetFolder.name) {
                        store.moveNote(note.id, toFolder: targetFolder.id)
                    }
                }
            }
        }
        Button("Copy") {
            copy(note.text)
        }
        Button(note.isRead ? "Mark as unread" : "Mark as read") {
            note.isRead ? store.markUnread(note.id) : store.markRead(note.id)
        }
        Button("Delete", role: .destructive) {
            store.delete(note)
            store.selectedNoteID = nil
        }
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func openInFloatingViewer(_ note: Note) {
        store.viewerNoteID = note.id
        openWindow(id: "note-viewer")
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct TodayNoteEditorContainer: View {
    @ObservedObject var store: NotesStore
    let note: Note

    var body: some View {
        NoteEditorView(store: store, note: note)
    }
}

private struct FolderNoteListRow: View {
    let note: Note
    var onOpenViewer: (() -> Void)? = nil
    let onSelect: () -> Void
    @State private var isHovering = false
    @AppAccent private var accent

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        if !note.isRead {
                            Circle()
                                .fill(accent.color)
                                .frame(width: 7, height: 7)
                                .accessibilityLabel("Unread")
                        }

                        Text(note.title)
                            .font(.body.weight(note.isRead ? .semibold : .bold))
                            .lineLimit(1)
                    }

                    Text(note.preview)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(note.updatedAt, style: .relative)
                        Text("\(note.wordCount) words")
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }

                Spacer()

                if let onOpenViewer, isHovering {
                    Button {
                        onOpenViewer()
                    } label: {
                        Image(systemName: "rectangle.on.rectangle")
                    }
                    .buttonStyle(.borderless)
                    .help("Open in floating window")
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isHovering ? .secondary : .tertiary)
                    .padding(.top, 3)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering ? accent.color.opacity(0.16) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
