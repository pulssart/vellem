import Combine
import Foundation

@MainActor
final class MobileNotesStore: ObservableObject {
    struct Pending: Codable, Identifiable {
        let action: MobileAction
        var error: String?
        var id: UUID { action.id }
    }
    private struct Snapshot: Codable { var notes: [Note]; var folders: [Folder] }
    @Published private(set) var notes: [Note] = []
    @Published private(set) var folders: [Folder] = []
    @Published private(set) var pending: [Pending] = []
    @Published private(set) var isLoading = false
    @Published var syncError: String?
    private var remote = Snapshot(notes: [], folders: [])
    private var refreshTimer: Timer?
    private var lastRefresh = Date.distantPast
    private var submitted = Set<UUID>()
    private let defaults = UserDefaults.standard
    nonisolated private static var cache: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appending(path: "vellem-mailbox.json")
    }

    init() {
        if let data = defaults.data(forKey: "mobileOutbox.v1"),
           let saved = try? JSONDecoder().decode([Pending].self, from: data) { pending = saved }
    }

    func start() {
        guard refreshTimer == nil else { return }
        Task {
            if let cache = await Task.detached(priority: .utility, operation: { try? JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: Self.cache)) }).value, remote.notes.isEmpty {
                remote = cache; project()
            }
            await refresh(shouldNotify: false)
        }
        refreshTimer = .scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, Date().timeIntervalSince(self.lastRefresh) >= (self.pending.isEmpty ? 25 : 4) else { return }
                await self.refresh()
            }
        }
    }
    func stop() { refreshTimer?.invalidate(); refreshTimer = nil }

    func refresh(shouldNotify: Bool = true) async {
        guard !isLoading else { return }
        isLoading = true; lastRefresh = .now
        defer { isLoading = false }
        let outgoing = pending.filter { $0.error == nil }.map(\.action)
        let previouslySubmitted = submitted
        do {
            let (snapshot, receipts, sent) = try await Task.detached(priority: .utility) {
                guard let root = CloudMirrorStore.containerURL else { throw CloudMirrorError.unavailable }
                var receipts = [UUID: MobileReceipt](), sent = Set<UUID>()
                for item in outgoing {
                    let file = MobileMailboxFiles.result(item.id, in: root)
                    if let receipt = try? MobileMailboxFiles.read(MobileReceipt.self, from: file) { receipts[item.id] = receipt }
                    else if !previouslySubmitted.contains(item.id) {
                        try MobileMailboxFiles.submit(item, in: root)
                        sent.insert(item.id)
                    }
                }
                let notes = try CloudMirrorStore.loadNotes([Note].self)
                let folders = try CloudMirrorStore.loadFolders([Folder].self)
                let snapshot = Snapshot(notes: notes.sorted { $0.updatedAt > $1.updatedAt }, folders: folders)
                let encoder = JSONEncoder()
                encoder.outputFormatting = .sortedKeys
                let data = try encoder.encode(snapshot)
                if (try? Data(contentsOf: Self.cache)) != data { try? data.write(to: Self.cache, options: .atomic) }
                return (snapshot, receipts, sent)
            }.value
            remote = snapshot; submitted.formUnion(sent)
            var settled = Set<UUID>()
            for i in pending.indices {
                let item = pending[i], action = item.action
                if let receipt = receipts[item.id] {
                    if let error = receipt.error { pending[i].error = error }
                    else if case .reply = action.kind {
                        if replyIsSettled(action) { settled.insert(item.id) }
                    } else { settled.insert(item.id) }
                } else if replyIsSettled(action) { settled.insert(item.id) }
            }
            pending.removeAll { settled.contains($0.id) }; submitted.subtract(settled)
            savePending(); project(); syncError = nil
            MobileFolderNotificationScanner.scan(notes: notes, folders: folders, shouldNotify: shouldNotify)
        } catch CloudMirrorError.unavailable {
            syncError = "iCloud Drive is unavailable. Pending actions are saved on this iPhone."
        } catch {
            syncError = "Your iCloud library is unavailable. Open Vellem on your Mac, then refresh your inbox."
        }
    }

    nonisolated private static func agent(_ note: Note, folders: [Folder]) -> InboxAgent? {
        if let sender = InboxAgent.origin(of: note) { return sender }
        guard note.sourceApp == nil || note.sourceApp == "MCP", let id = note.folderID,
              let f = folders.first(where: { $0.id == id }) else { return nil }
        return f.kind == .smartCodex ? .codex : f.kind == .smartClaude ? .claude : nil
    }
    func agent(for note: Note) -> InboxAgent? { Self.agent(note, folders: folders) }
    func agentFolders(_ agent: InboxAgent) -> [Folder] {
        SidebarMailbox.agent(agent).visibleFolders(in: folders, notes: notes)
    }
    func notes(in agent: InboxAgent) -> [Note] {
        notes(in: .agent(agent))
    }
    func notes(in scope: MailScope) -> [Note] {
        notes.filter { !$0.isDailyNote && contains($0, in: scope) }
    }
    func hasUnread(in scope: MailScope) -> Bool {
        notes.contains { !$0.isRead && !$0.isDailyNote && contains($0, in: scope) }
    }
    private func contains(_ note: Note, in scope: MailScope) -> Bool {
        switch scope {
        case .all: true
        case .folder(let id): note.folderID == id
        case .agent(let agent):
            self.agent(for: note) == agent || folders.first(where: { $0.id == note.folderID })?.mailbox == agent.rawValue
        }
    }
    func markRead(_ note: Note) { if !note.isRead { enqueue(.read(note: note.id)) } }
    func createFolder(_ name: String, for agent: InboxAgent) -> Bool {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 100, !agentFolders(agent).contains(where: { $0.name.localizedCaseInsensitiveCompare(value) == .orderedSame }) else { return false }
        enqueue(.createFolder(id: UUID(), name: value, agent: agent.rawValue)); return true
    }
    @discardableResult
    func move(_ note: Note, to folder: UUID?) -> Bool {
        guard note.folderID != folder else { return false }
        enqueue(.move(note: note.id, folder: folder))
        return true
    }
    @discardableResult
    func send(_ text: String, to note: Note) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, note.conversation != nil else { return false }
        enqueue(.reply(note: note.id, text: value))
        return true
    }
    func dismiss(_ item: Pending) { pending.removeAll { $0.id == item.id }; savePending(); project() }
    private func enqueue(_ kind: MobileAction.Kind) {
        pending.append(Pending(action: MobileAction(kind: kind))); savePending(); project()
        Task { await refresh(shouldNotify: false) }
    }
    private func savePending() { if let data = try? JSONEncoder().encode(pending) { defaults.set(data, forKey: "mobileOutbox.v1") } }
    private func replyIsSettled(_ action: MobileAction) -> Bool {
        guard case .reply(let id, _) = action.kind else { return false }
        return remote.notes.first(where: { $0.id == id })?.replies?.contains { $0.id == action.id } == true
    }
    private func project() {
        var items = remote.notes, boxes = remote.folders
        for item in pending where item.error == nil {
            switch item.action.kind {
            case .read(let id):
                if let i = items.firstIndex(where: { $0.id == id }) { items[i].isRead = true }
            case .move(let id, let folder):
                if let i = items.firstIndex(where: { $0.id == id }) {
                    if InboxAgent.origin(of: items[i]) == nil, let agent = Self.agent(items[i], folders: boxes) {
                        items[i].sourceApp = agent.rawValue
                    }
                    items[i].folderID = folder
                }
            case .createFolder(let id, let name, let agent):
                if !boxes.contains(where: { $0.id == id }) { boxes.append(Folder(id: id, name: name, mailbox: agent)) }
            case .reply: break
            }
        }
        if notes != items { notes = items }; if folders != boxes { folders = boxes }
    }
}
