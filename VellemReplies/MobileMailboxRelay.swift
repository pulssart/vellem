import Foundation

final class MobileMailboxRelay: @unchecked Sendable {
    private let queue = DispatchQueue(label: "Vellem.mobileMailbox", qos: .utility)
    private var libraryStamp: [Date] = []
    private var missingSince = [UUID: Date]()
    private var lastReplyScan: Date?
    private var hasQueuedReplies = false
    private var nextAttachmentSync = Date.distantPast

    func refresh(using service: ReplyService, completion: @escaping @Sendable () -> Void) {
        queue.async {
            defer { completion() }
            let store = NotesFileStore()
            do { try self.collectCodexReplies(in: store) }
            catch { NSLog("Vellem Codex reply sync: %@", error.localizedDescription) }
            guard let cloud = CloudMirrorStore.containerURL else { return }
            do {
                try self.publishLibrary(store.libraryDirectory, to: cloud)
                if Date() >= self.nextAttachmentSync {
                    try self.publishAttachments(store.libraryDirectory, to: cloud)
                    self.nextAttachmentSync = Date.now.addingTimeInterval(60)
                }
            } catch { NSLog("Vellem mobile mirror: %@", error.localizedDescription) }
            let requests = MobileMailboxFiles.requests(in: cloud)
            guard let files = try? FileManager.default.contentsOfDirectory(at: requests, includingPropertiesForKeys: nil) else { return }
            let actions = files.compactMap { entry -> MobileAction? in
                let name = entry.lastPathComponent
                let file = name.hasPrefix(".") && name.hasSuffix(".json.icloud")
                    ? requests.appending(path: String(name.dropFirst().dropLast(".icloud".count)))
                    : entry
                guard file.pathExtension == "json", let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent),
                      let action = try? MobileMailboxFiles.read(MobileAction.self, from: file), action.id == id else { return nil }
                return action
            }.sorted { $0.date < $1.date }
            for action in actions {
                do { try self.consume(action, store: store, cloud: cloud, service: service) }
                catch { NSLog("Vellem mobile relay: %@", error.localizedDescription) }
            }
        }
    }

    private func collectCodexReplies(in store: NotesFileStore) throws {
        let file = store.libraryDirectory.appending(path: "notes.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        let stamp = try file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        guard hasQueuedReplies || stamp != lastReplyScan else { return }
        let notes = try store.listNotes(limit: .max)
        let pending = notes.filter { $0.replies?.contains(where: { $0.delivery == .queued }) == true }
        hasQueuedReplies = !pending.isEmpty
        lastReplyScan = stamp
        guard hasQueuedReplies else { return }
        let client = try CodexReplyQueue()
        for note in pending {
            guard let conversation = note.conversation, conversation.provider == .codex else { continue }
            for reply in note.replies ?? [] where reply.delivery == .queued {
                do {
                    switch try client.status(of: reply, thread: conversation.sessionID) {
                    case .waiting:
                        missingSince[reply.id] = nil
                    case .finished(let result):
                        try store.appendReply(result, to: note.id, in: conversation)
                        missingSince[reply.id] = nil
                    case .absent:
                        // A queue removal can be visible before the turn is saved to history.
                        guard let since = missingSince[reply.id] else { missingSince[reply.id] = .now; continue }
                        guard Date().timeIntervalSince(since) > 60 else { continue }
                        var result = reply
                        result.delivery = .failed
                        result.answer = "Ce message ne figure plus dans la file ni dans l’historique du chat Codex."
                        try store.appendReply(result, to: note.id, in: conversation)
                        missingSince[reply.id] = nil
                    }
                } catch {
                    NSLog("Vellem Codex reply sync: %@", error.localizedDescription)
                }
            }
        }
    }

    private func publishLibrary(_ local: URL, to cloud: URL) throws {
        let files = ["notes.json", "folders.json"].map { local.appending(path: $0) }
        let stamp = try files.map { try $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast }
        guard stamp != libraryStamp else { return }
        try LibraryWriteLock.withLock(in: local) {
            try CloudMirrorStore.publish(notesData: Data(contentsOf: files[0]), foldersData: Data(contentsOf: files[1]))
        }
        libraryStamp = stamp
    }

    private func publishAttachments(_ local: URL, to cloud: URL) throws {
        let root = local.appending(path: "Attachments").standardizedFileURL
        let target = cloud.appending(path: "Attachments")
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]
        guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else { return }
        for case let file as URL in files {
            let info = try file.resourceValues(forKeys: keys)
            guard info.isSymbolicLink != true, info.isRegularFile == true,
                  ["png","jpg","jpeg","webp","gif","heic","avif"].contains(file.pathExtension.lowercased()) else { continue }
            let destination = target.appending(path: String(file.standardizedFileURL.path.dropFirst(root.path.count + 1)))
            if let existing = try? destination.resourceValues(forKeys: keys), existing.fileSize == info.fileSize,
               let date = existing.contentModificationDate, date >= (info.contentModificationDate ?? .distantPast) { continue }
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try CloudMirrorStore.write(Data(contentsOf: file, options: .mappedIfSafe), to: destination)
        }
    }

    private func consume(_ action: MobileAction, store: NotesFileStore, cloud: URL, service: ReplyService) throws {
        let result = MobileMailboxFiles.result(action.id, in: cloud)
        let source = MobileMailboxFiles.requests(in: cloud).appending(path: action.id.uuidString + ".json")
        let marker = store.libraryDirectory.appending(path: "MobileProcessed").appending(path: action.id.uuidString + ".json")
        // Persist the receipt locally before removing the cloud request. A second delivery cannot repeat a CLI turn.
        func finish(_ error: String?) throws {
            let receipt = MobileReceipt(error: error)
            try MobileMailboxFiles.write(receipt, to: marker)
            try MobileMailboxFiles.write(receipt, to: result)
            try? FileManager.default.removeItem(at: source)
        }
        if let prior = try? MobileMailboxFiles.read(MobileReceipt.self, from: marker) { try finish(prior.error); return }
        if case .reply(let noteID, let text) = action.kind {
            guard let note = try store.getNote(id: noteID) else { try finish("Le rapport n’est plus disponible sur le Mac."); return }
            if note.replies?.contains(where: { $0.id == action.id }) == true { try finish(nil); return }
            let claim = marker.deletingPathExtension().appendingPathExtension("claim")
            try FileManager.default.createDirectory(at: claim.deletingLastPathComponent(), withIntermediateDirectories: true)
            let fd = open(claim.path, O_CREAT | O_EXCL | O_WRONLY, 0o600)
            guard fd >= 0 else {
                guard errno == EEXIST else { throw CocoaError(.fileWriteUnknown) }
                let date = try claim.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .now
                if Date().timeIntervalSince(date) > 360 { try finish("Envoi interrompu. Vérifie le fil sur le Mac avant de réessayer.") }
                return
            }
            close(fd)
            let semaphore = DispatchSemaphore(value: 0)
            service.send(noteID: noteID.uuidString, requestID: action.id.uuidString, question: text) { error in
                defer { semaphore.signal() }
                do {
                    try MobileMailboxFiles.write(MobileReceipt(error: error), to: marker)
                } catch { NSLog("Vellem mobile receipt: %@", error.localizedDescription) }
            }
            semaphore.wait()
            let receipt = try MobileMailboxFiles.read(MobileReceipt.self, from: marker)
            try finish(receipt.error)
            try? FileManager.default.removeItem(at: claim)
        } else {
            do { try store.applyMobileChange(action) }
            catch { try finish(error.localizedDescription); return }
            try finish(nil)
        }
    }
}
