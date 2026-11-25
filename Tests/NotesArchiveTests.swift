import Foundation

@main
enum NotesArchiveTests {
    static func main() throws {
        guard VellemStorageEnvironment.isolatedDirectory != nil else {
            fatalError("Archive tests require an isolated library")
        }
        try FileManager.default.createDirectory(at: AppGroup.attachmentsURL, withIntermediateDirectories: true)
        let original = AppGroup.attachmentsURL.appending(path: "image.txt")
        try Data("existing attachment".utf8).write(to: original)
        UserDefaults.standard.set(false, forKey: AppPreferences.showDockIconKey)
        var hiddenAgents = HiddenInboxAgents()
        precondition(InboxAgent.allCases.allSatisfy(hiddenAgents.isVisible))
        for agent in InboxAgent.allCases { hiddenAgents.setVisible(false, for: agent) }
        precondition(InboxAgent.allCases.filter(hiddenAgents.isVisible).isEmpty)
        hiddenAgents.setVisible(true, for: .claude)
        let restoredAgents = HiddenInboxAgents(rawValue: hiddenAgents.rawValue)
        precondition(InboxAgent.allCases.filter(restoredAgents.isVisible) == [.claude])
        UserDefaults.standard.set(hiddenAgents.rawValue, forKey: AppPreferences.hiddenInboxAgentsKey)
        let note = Note(text: "# Note\n\n![Image](\(original.absoluteString))")
        let archive = try NotesArchiveService.archiveData(notes: [note], folders: []).data
        UserDefaults.standard.set(true, forKey: AppPreferences.showDockIconKey)
        UserDefaults.standard.removeObject(forKey: AppPreferences.hiddenInboxAgentsKey)

        var object = try JSONSerialization.jsonObject(with: archive) as! [String: Any]
        // An archive from the previous UI can contain a palette alongside valid settings.
        var preferences = object["preferences"] as! [String: Any]
        var standard = preferences["standard"] as! [String: Any]
        let plist = Data(base64Encoded: standard["propertyListBase64"] as! String)!
        var defaults = try PropertyListSerialization.propertyList(from: plist, format: nil) as! [String: Any]
        defaults["appAccentColor"] = "blue"
        standard["propertyListBase64"] = try PropertyListSerialization.data(fromPropertyList: defaults, format: .binary, options: 0).base64EncodedString()
        preferences["standard"] = standard
        object["preferences"] = preferences
        let accentBeforeImport = UserDefaults.standard.string(forKey: "appAccentColor")
        var attachments = object["attachments"] as! [[String: Any]]
        attachments[0]["dataBase64"] = Data("imported attachment".utf8).base64EncodedString()
        object["attachments"] = attachments
        let modifiedArchive = try JSONSerialization.data(withJSONObject: object)
        let imported = try NotesArchiveService.importArchive(from: modifiedArchive)
        let originalAfterImport = try String(contentsOf: original, encoding: .utf8)
        precondition(originalAfterImport == "existing attachment")
        let directories = try FileManager.default.contentsOfDirectory(at: AppGroup.attachmentsURL, includingPropertiesForKeys: nil)
        guard let importedDirectory = directories.first(where: { $0.lastPathComponent.hasPrefix("Import-") }) else {
            fatalError("The imported attachment directory is missing")
        }
        let importedAttachment = importedDirectory.appending(path: "image.txt")
        let importedContent = try String(contentsOf: importedAttachment, encoding: .utf8)
        precondition(importedContent == "imported attachment")
        guard let markdownStart = imported.notes[0].text.range(of: "![Image](")?.upperBound,
              let markdownEnd = imported.notes[0].text[markdownStart...].firstIndex(of: ")"),
              let linkedURL = URL(string: String(imported.notes[0].text[markdownStart..<markdownEnd])) else {
            fatalError("The restored attachment link is missing")
        }
        precondition(linkedURL.resolvingSymlinksInPath() == importedAttachment.resolvingSymlinksInPath())
        precondition(UserDefaults.standard.bool(forKey: AppPreferences.showDockIconKey))
        imported.restorePreferences()
        precondition(!UserDefaults.standard.bool(forKey: AppPreferences.showDockIconKey))
        precondition(UserDefaults.standard.string(forKey: AppPreferences.hiddenInboxAgentsKey) == hiddenAgents.rawValue)
        precondition(UserDefaults.standard.string(forKey: "appAccentColor") == accentBeforeImport)

        object["schemaVersion"] = 999
        let futureArchive = try JSONSerialization.data(withJSONObject: object)
        do {
            _ = try NotesArchiveService.importArchive(from: futureArchive)
            fatalError("An unsupported archive schema must be rejected")
        } catch NotesArchiveError.invalidArchive { }

        object["schemaVersion"] = 1
        attachments[0]["relativePath"] = "../outside.txt"
        object["attachments"] = attachments
        let invalidPathArchive = try JSONSerialization.data(withJSONObject: object)
        do {
            _ = try NotesArchiveService.importArchive(from: invalidPathArchive)
            fatalError("Unsafe attachment paths must be rejected")
        } catch NotesArchiveError.invalidAttachmentPath(_) { }
        let originalAfterInvalidImport = try String(contentsOf: original, encoding: .utf8)
        precondition(originalAfterInvalidImport == "existing attachment")
        print("Archive: existing attachments preserved, preferences deferred, invalid version and path rejected")
    }
}
