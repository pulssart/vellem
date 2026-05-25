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
    private let headerIconSize: CGFloat = 20
    private let emptyStateIconSize: CGFloat = 28
    private let smartFolderInk = Color(nsColor: NSColor(calibratedWhite: 0.22, alpha: 1))

    private var notes: [Note] {
        store.notesForDisplay(in: folder)
    }

    private var workflowTargetApp: AgentApp {
        switch folder.kind {
        case .smartClaude:
            .claude
        case .smartCodex, .smartPromptLibrary:
            .codex
        default:
            .claude
        }
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
                            FolderNoteListRow(note: note, isSelected: store.selectedNoteID == note.id, onOpenViewer: {
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
            VStack(alignment: .leading, spacing: folder.kind == .smartPromptLibrary ? 22 : 10) {
                if folder.kind != .smartPromptLibrary {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Ready-to-use workflows")
                            .font(.headline)

                        Spacer()

                        Text("Copy a prompt, paste it into \(folder.name).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if folder.kind == .smartPromptLibrary {
                    ForEach(AgentWorkflowCategory.allCases) { category in
                        let categoryWorkflows = workflows.filter { $0.category == category }
                        if !categoryWorkflows.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(category.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 18)], spacing: 18) {
                                    ForEach(categoryWorkflows) { workflow in
                                        workflowCard(workflow)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                        ForEach(workflows) { workflow in
                            workflowCard(workflow)
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
                .font(.system(size: headerIconSize, weight: .semibold))
                .foregroundStyle(folder.isSmart ? smartFolderInk : (FolderColor.named(folder.color)?.swiftUIColor ?? accent.color))

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
            } else if folder.kind == .smartPromptLibrary {
                ScrollView {
                    VStack(spacing: 16) {
                        workflowCards
                    }
                    .padding(20)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: folder.outlineSystemImage)
                        .font(.system(size: emptyStateIconSize, weight: .regular))
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
                .font(.system(size: emptyStateIconSize, weight: .regular))
                .foregroundStyle(folder.isSmart ? smartFolderInk : (FolderColor.named(folder.color)?.swiftUIColor ?? accent.color))

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

    private func workflowCard(_ workflow: AgentWorkflow) -> some View {
        AgentWorkflowCard(
            workflow: workflow,
            isCopied: copiedWorkflowID == workflow.id,
            targetApp: workflowTargetApp
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

private enum AgentWorkflowCategory: String, CaseIterable, Identifiable {
    case research
    case meetings
    case product
    case design
    case docs
    case inbox

    var id: String { rawValue }

    var title: String {
        switch self {
        case .research:
            "Research and interviews"
        case .meetings:
            "Meetings and coordination"
        case .product:
            "Product and execution"
        case .design:
            "Design and feedback"
        case .docs:
            "Docs, sheets, and slides"
        case .inbox:
            "Inbox and customer signals"
        }
    }
}

private struct AgentWorkflow: Identifiable {
    let id: String
    let title: String
    let description: String
    let systemImage: String
    let prompt: String
    var category: AgentWorkflowCategory?
    var tools: [KnownTool] = []

    static func workflows(for folder: Folder) -> [AgentWorkflow] {
        switch folder.kind {
        case .smartPromptLibrary:
            return promptLibraryWorkflows
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
            """,
            tools: [.slack, .gmail]
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
            """,
            tools: [.calendar, .granola]
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
            """,
            tools: [.linear]
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
            """,
            tools: [.figma]
        ),
        AgentWorkflow(
            id: "today-notion-digest",
            title: "Notion knowledge digest",
            description: "Summarize today's Notion changes worth knowing.",
            systemImage: "doc.text.below.ecg",
            prompt: """
            Scan Notion for pages and databases updated in the last 24 hours.
            Summarize what changed, who changed it, and which pages matter for the team this week.
            Highlight decisions logged, specs updated, and new docs worth reading.
            Append this knowledge digest to today's Vellem note with `append_to_daily`.
            """,
            tools: [.notion]
        ),
        AgentWorkflow(
            id: "today-maxi-recap",
            title: "Daily maxi recap",
            description: "Everything that mattered today across your stack.",
            systemImage: "sparkles.rectangle.stack",
            prompt: """
            Build a comprehensive end-of-day recap by pulling from every connected tool:

            - **Calendar** — meetings held today, attendees, key outcomes.
            - **Granola** — decisions, action items, and open questions captured in meeting notes.
            - **Slack** — important threads, mentions, decisions reached, requests awaiting an answer.
            - **Gmail** — emails that need a reply, contracts, deliverables, customer signals.
            - **Linear** — issues moved, blockers, comments needing follow-up, next-up tickets.
            - **Notion** — pages and databases updated today worth knowing about.
            - **Figma** — design changes, feedback, screens ready for handoff.

            Organize the recap by area (people / projects / product / design / inbox).
            Lead with what changed, then what to do next.
            Append the full recap to today's Vellem note with `append_to_daily`.
            Keep each section tight — a few crisp lines, not a wall of text.
            """,
            tools: [.calendar, .granola, .slack, .gmail, .linear, .notion, .figma]
        )
    ]

    private static let promptLibraryWorkflows: [AgentWorkflow] = [
        AgentWorkflow(
            id: "prompt-user-interview-summary",
            title: "Granola user interview summary",
            description: "Turn a raw interview into a clean product readout.",
            systemImage: "person.crop.rectangle.stack",
            prompt: """
            Review the relevant Granola note for this user interview.
            Use the Vellem MCP throughout. Start with `search_notes` to find prior customer notes, previous interviews, and any existing context in the Codex or research folders.
            Then produce a structured summary with these sections: who the user is, team and role, current product usage, workflow, goals, needs, expectations, frustrations, workarounds, quotes worth keeping, feature requests, ideas for improvement, and signals that should influence roadmap priority.
            End with three parts: what changed our understanding, what to do next, and open questions to validate in the next interview.
            Save the final write-up to Vellem with `add_note`, use a clear title, and store it in the `Codex` folder.
            If the interview creates concrete tasks, also create a Vellem checklist with `create_todo_list`.
            """,
            category: .research,
            tools: [.granola, .notion, .linear]
        ),
        AgentWorkflow(
            id: "prompt-meeting-summary-todos",
            title: "Granola meeting summary and todo",
            description: "Extract decisions, owners, and next moves from a meeting.",
            systemImage: "checklist.checked",
            prompt: """
            Review the Granola note for this meeting.
            Use the Vellem MCP throughout. First run `search_notes` to recover prior notes, decision logs, and open follow-ups on the same topic.
            Write a tight meeting recap with: purpose, attendees, context, decisions made, work agreed, blockers, unanswered questions, and what needs to happen next.
            Then convert the action items into an actionable Vellem checklist with `create_todo_list`, each item with a verb and an owner when available.
            Save the meeting summary to Vellem with `add_note` in the `Codex` folder, and append a short version to today with `append_to_daily`.
            """,
            category: .meetings,
            tools: [.granola, .calendar, .notion]
        ),
        AgentWorkflow(
            id: "prompt-weekly-research-digest",
            title: "Weekly research digest",
            description: "Merge interviews into one clear product signal report.",
            systemImage: "chart.bar.doc.horizontal",
            prompt: """
            Look across the latest Granola interview notes and related Notion research docs.
            Use the Vellem MCP throughout. Start with `search_notes` to gather previous syntheses and avoid repeating old conclusions.
            Build a weekly digest grouped by themes: repeated pains, unmet needs, buying signals, product confusion, feature requests, and patterns by segment.
            Finish with what the product team should change this week.
            Save the digest with `add_note` to the `Codex` folder, and create a Vellem todo list for the follow-ups that deserve action.
            """,
            category: .research,
            tools: [.granola, .notion]
        ),
        AgentWorkflow(
            id: "prompt-calendar-brief",
            title: "Meeting prep brief",
            description: "Prepare before a call with context from your stack.",
            systemImage: "calendar.badge.exclamationmark",
            prompt: """
            Review the upcoming Google Calendar event, then gather context from Gmail, Slack, Granola, and Vellem.
            Use the Vellem MCP throughout. Run `search_notes` first for prior meeting notes, decision logs, and open questions.
            Write a concise prep brief with attendee context, current project state, last decisions, risks to address, and the five questions that matter most.
            Save it to Vellem with `add_note` in `Codex`, then append a very short version to today with `append_to_daily`.
            """,
            category: .meetings,
            tools: [.calendar, .gmail, .slack, .granola]
        ),
        AgentWorkflow(
            id: "prompt-slack-decision-log",
            title: "Slack decision log",
            description: "Turn noisy threads into durable decisions.",
            systemImage: "text.bubble",
            prompt: """
            Review the relevant Slack thread.
            Use the Vellem MCP throughout. Search Vellem first with `search_notes` for earlier context, then summarize the thread into: issue, options discussed, decision, rationale, trade-offs, people involved, and what still needs an answer.
            Save the decision log with `add_note` in the `Codex` folder.
            If the thread contains work to do, create a checklist in Vellem with `create_todo_list`.
            """,
            category: .meetings,
            tools: [.slack]
        ),
        AgentWorkflow(
            id: "prompt-slack-escalations",
            title: "Slack requests awaiting answer",
            description: "Find asks that are sitting there and need a reply.",
            systemImage: "bubble.left.and.exclamationmark.bubble.right",
            prompt: """
            Scan recent Slack activity and identify requests, mentions, or blocked threads still waiting for an answer.
            Use the Vellem MCP throughout. Search existing Vellem notes first so you can link each request to the right project context.
            Return a short triage by priority: what needs a reply today, what can wait, and what should become a task.
            Save the triage to Vellem with `add_note`, then create a Vellem todo list for the items that need follow-up.
            """,
            category: .inbox,
            tools: [.slack]
        ),
        AgentWorkflow(
            id: "prompt-linear-ship-room",
            title: "Linear ship room",
            description: "Turn issue movement into a focused execution note.",
            systemImage: "shippingbox",
            prompt: """
            Review recent Linear issue movement for the project.
            Use the Vellem MCP throughout. Start with `search_notes` to recover previous plans, bug logs, and release notes.
            Summarize what moved forward, what is blocked, which comments need follow-up, and what the team should tackle next.
            Save the execution note with `add_note` in `Codex`, then create a Vellem todo list for next-up tickets and blockers.
            """,
            category: .product,
            tools: [.linear, .notion]
        ),
        AgentWorkflow(
            id: "prompt-linear-spec-gap",
            title: "Spec gap finder",
            description: "Compare Linear work against Notion docs and find holes.",
            systemImage: "arrow.left.and.right.text.vertical",
            prompt: """
            Compare the active Linear tickets with the relevant Notion product spec.
            Use the Vellem MCP throughout. Search Vellem first for prior audits and implementation notes.
            Produce a gap review with: unclear acceptance criteria, missing dependencies, unresolved design decisions, outdated documentation, and risks before shipping.
            Save it to Vellem with `add_note` in `Codex`.
            If the gaps are actionable, create a Vellem checklist with `create_todo_list`.
            """,
            category: .product,
            tools: [.linear, .notion]
        ),
        AgentWorkflow(
            id: "prompt-roadmap-from-signals",
            title: "Roadmap from signals",
            description: "Combine interviews, tickets, and support into a priority view.",
            systemImage: "point.topleft.down.curvedto.point.bottomright.up",
            prompt: """
            Pull product signals from Granola, Gmail, Slack, Linear, and Notion.
            Use the Vellem MCP throughout. Search Vellem for previous roadmap notes and decision logs before you synthesize.
            Group the insights into themes, score them by urgency and impact, then propose what deserves to move onto the roadmap now, later, or never.
            Save the roadmap note to Vellem with `add_note`, and create a checklist for the top priority investigations.
            """,
            category: .product,
            tools: [.granola, .gmail, .slack, .linear, .notion]
        ),
        AgentWorkflow(
            id: "prompt-figma-feedback-summary",
            title: "Figma feedback summary",
            description: "Collect design changes, comments, and what is ready.",
            systemImage: "paintbrush.pointed",
            prompt: """
            Review the relevant Figma file and comments.
            Use the Vellem MCP throughout. Start with `search_notes` to find earlier design reviews, product decisions, and handoff notes.
            Summarize changed screens, key feedback, decisions made, unresolved UX questions, and what is ready for handoff.
            Save the summary to Vellem with `add_note` in `Codex`, and add a todo list for the design or engineering follow-ups if needed.
            """,
            category: .design,
            tools: [.figma, .notion]
        ),
        AgentWorkflow(
            id: "prompt-design-handoff",
            title: "Design handoff pack",
            description: "Turn Figma into something engineering can actually use.",
            systemImage: "square.and.arrow.down.on.square",
            prompt: """
            Review the target Figma screens and the linked product context.
            Use the Vellem MCP throughout. Search prior implementation notes in Vellem first.
            Produce a handoff note with the purpose of the flow, changed states, edge cases, copy details, interaction notes, open implementation questions, and what must not regress.
            Save it to Vellem with `add_note` in `Codex`, and create a Vellem checklist for the implementation steps.
            """,
            category: .design,
            tools: [.figma, .linear, .notion]
        ),
        AgentWorkflow(
            id: "prompt-notion-spec-summary",
            title: "Notion spec summary",
            description: "Shrink a long spec into something readable and useful.",
            systemImage: "doc.richtext",
            prompt: """
            Review the relevant Notion page or database entry.
            Use the Vellem MCP throughout. Run `search_notes` first for earlier summaries, decisions, and implementation notes.
            Summarize the spec into: problem, target user, scope, non-goals, key requirements, risks, open questions, and next actions.
            Save the result to Vellem with `add_note` in `Codex`.
            If the spec implies concrete work, create a Vellem checklist with `create_todo_list`.
            """,
            category: .docs,
            tools: [.notion]
        ),
        AgentWorkflow(
            id: "prompt-google-doc-brief",
            title: "Google Doc exec brief",
            description: "Turn a doc into a compact brief with the decisions exposed.",
            systemImage: "doc.plaintext",
            prompt: """
            Review the Google Doc.
            Use the Vellem MCP throughout. Search Vellem first for earlier context and duplicate summaries.
            Write a compact brief with: what this doc is about, what changed, the decisions inside it, what still needs a call, and what the team should do next.
            Save the brief to Vellem with `add_note`, and append the top three points to today with `append_to_daily` if they matter now.
            """,
            category: .docs,
            tools: [.googleDocs]
        ),
        AgentWorkflow(
            id: "prompt-google-sheet-signals",
            title: "Google Sheet signal readout",
            description: "Turn a sheet into product signals, not spreadsheet soup.",
            systemImage: "tablecells",
            prompt: """
            Review the Google Sheet and identify the signals that matter.
            Use the Vellem MCP throughout. Search Vellem first for previous analyses so you can compare trends instead of restating the obvious.
            Summarize the important numbers, anomalies, patterns, risks, and questions that need investigation.
            Save the readout to Vellem with `add_note`, and create a Vellem checklist for the follow-up analyses or fixes.
            """,
            category: .docs,
            tools: [.googleSheets, .linear]
        ),
        AgentWorkflow(
            id: "prompt-google-slides-review",
            title: "Slides review memo",
            description: "Review a deck and call out what lands, what confuses, what is missing.",
            systemImage: "menucard",
            prompt: """
            Review the Google Slides deck.
            Use the Vellem MCP throughout. Search Vellem first for prior positioning notes, product docs, and meeting context.
            Write a review memo with narrative quality, clarity of the ask, weak slides, missing proof points, and what should change before the next presentation.
            Save it to Vellem with `add_note` in `Codex`.
            If the deck needs a revision plan, create a Vellem checklist.
            """,
            category: .docs,
            tools: [.googleSlides, .notion]
        ),
        AgentWorkflow(
            id: "prompt-gmail-replies",
            title: "Emails needing reply",
            description: "Surface the mails that should not rot in the inbox.",
            systemImage: "envelope.badge",
            prompt: """
            Review recent Gmail threads and identify emails that need a reply.
            Use the Vellem MCP throughout. Search Vellem first for linked project notes, previous decisions, and customer context.
            Group the output into urgent replies, contracts or deliverables, customer signals, and threads that can be ignored.
            Save the triage to Vellem with `add_note`, and create a Vellem todo list for the replies that must go out today.
            """,
            category: .inbox,
            tools: [.gmail]
        ),
        AgentWorkflow(
            id: "prompt-customer-health-brief",
            title: "Customer health brief",
            description: "Merge inbox, Slack, and meetings into one account view.",
            systemImage: "heart.text.square",
            prompt: """
            Pull customer signals from Gmail, Slack, Granola, and Notion.
            Use the Vellem MCP throughout. Search Vellem first for previous account notes and follow-ups.
            Build a health brief with current relationship status, goals, friction points, risk signals, asks from the customer, and the next move we should make.
            Save it with `add_note` in `Codex`, and create a Vellem checklist for the account actions.
            """,
            category: .inbox,
            tools: [.gmail, .slack, .granola, .notion]
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Image(systemName: workflow.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent.color)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(accent.color.opacity(isHovering ? 0.16 : 0.10))
                    )

                Spacer()

                Button(action: onCopy) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent.color)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(accent.color.opacity(isHovering ? 0.14 : 0.08))
                        )
                }
                .buttonStyle(.borderless)
                .help(isCopied ? "Copied" : "Copy prompt")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(workflow.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(workflow.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if !workflow.tools.isEmpty {
                ToolBadgeRow(tools: workflow.tools, size: 18)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isHovering ? accent.color.opacity(0.07) : Color(nsColor: .windowBackgroundColor))
                .shadow(color: Color.black.opacity(isHovering ? 0.09 : 0.045), radius: isHovering ? 14 : 8, x: 0, y: isHovering ? 8 : 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isHovering ? accent.color.opacity(0.50) : Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
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
    @AppAccent private var accent
    private let smartFolderInk = Color(nsColor: NSColor(calibratedWhite: 0.22, alpha: 1))

    private var notes: [Note] {
        store.notes
            .filter { Calendar.current.isDateInToday($0.createdAt) }
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.createdAt > rhs.createdAt
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if notes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(notes) { note in
                            TodayTimelineRow(note: note, isSelected: store.selectedNoteID == note.id, accent: accent.color, onOpenViewer: {
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
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(smartFolderInk)

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

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.tertiary)

            Text("No notes today")
                .font(.headline)

            Text("Notes created today will appear here in order.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
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

private struct TodayTimelineRow: View {
    let note: Note
    let isSelected: Bool
    let accent: Color
    var onOpenViewer: (() -> Void)? = nil
    let onSelect: () -> Void
    @State private var isHovering = false

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var timelineTime: String {
        Self.timeFormatter.string(from: note.createdAt)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 18) {
                Text(timelineTime)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? accent : .secondary)
                    .frame(width: 44, alignment: .trailing)
                    .padding(.top, 4)

                VStack(spacing: 0) {
                    Circle()
                        .fill(isSelected ? accent : (note.isRead ? Color.secondary.opacity(0.32) : accent))
                        .frame(width: 10, height: 10)

                    Rectangle()
                        .fill(Color.secondary.opacity(0.14))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 6)
                }
                .frame(width: 10)

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            if note.isDailyNote {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }

                            if !note.isRead {
                                Circle()
                                    .fill(accent)
                                    .frame(width: 7, height: 7)
                                    .accessibilityLabel("Unread")
                            }

                            Text(note.title)
                                .font(.body.weight(note.isRead ? .semibold : .bold))
                                .foregroundStyle(isSelected ? .primary : .primary)
                                .lineLimit(1)
                        }

                        Text(note.preview)
                            .font(.callout)
                            .foregroundStyle(isSelected ? Color.primary.opacity(0.8) : Color.secondary)
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            Text(note.updatedAt, style: .relative)
                            Text("\(note.wordCount) words")
                        }
                        .font(.caption)
                        .foregroundStyle(isSelected ? .secondary : .tertiary)
                    }

                    Spacer(minLength: 0)

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
                        .foregroundStyle(isSelected ? accent : (isHovering ? Color.secondary : Color.secondary.opacity(0.55)))
                        .padding(.top, 4)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? accent.opacity(0.24) : (isHovering ? accent.opacity(0.14) : Color(nsColor: .windowBackgroundColor)))
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
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
    var isSelected: Bool = false
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
                        .foregroundStyle(isSelected ? Color.primary.opacity(0.8) : Color.secondary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(note.updatedAt, style: .relative)
                        Text("\(note.wordCount) words")
                    }
                    .font(.caption)
                    .foregroundStyle(isSelected ? .secondary : .tertiary)
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
                    .foregroundStyle(isSelected ? accent.color : (isHovering ? Color.secondary : Color.secondary.opacity(0.55)))
                    .padding(.top, 3)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? accent.color.opacity(0.24) : (isHovering ? accent.color.opacity(0.16) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
