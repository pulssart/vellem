import Foundation

enum NotesArchiveError: LocalizedError {
    case invalidArchive
    case invalidAttachmentPath(String)
    case invalidAttachmentData(String)

    var errorDescription: String? {
        switch self {
        case .invalidArchive:
            "This file is not a Vellem archive."
        case .invalidAttachmentPath(let path):
            "Attachment path is not valid: \(path)"
        case .invalidAttachmentData(let path):
            "Attachment data is not valid: \(path)"
        }
    }
}

struct NotesArchiveSummary {
    let noteCount: Int
    let folderCount: Int
    let attachmentCount: Int
}

struct NotesArchiveImport {
    let notes: [Note]
    let folders: [Folder]
    let summary: NotesArchiveSummary
}

enum NotesArchiveService {
    private static let format = "com.adriendonot.Vellem.notesArchive"
    private static let schemaVersion = 1

    static func archiveData(notes: [Note], folders: [Folder]) throws -> (data: Data, summary: NotesArchiveSummary) {
        let archive = try archive(notes: notes, folders: folders)
        let data = try archiveEncoder.encode(archive)
        let summary = NotesArchiveSummary(
            noteCount: notes.count,
            folderCount: folders.count,
            attachmentCount: archive.attachments.count
        )
        return (data, summary)
    }

    static func exportArchive(notes: [Note], folders: [Folder], to url: URL) throws -> NotesArchiveSummary {
        let (data, summary) = try archiveData(notes: notes, folders: folders)
        try data.write(to: url, options: [.atomic])
        return summary
    }

    static func importArchive(from data: Data) throws -> NotesArchiveImport {
        let archive = try archiveDecoder.decode(NotesArchive.self, from: data)

        guard archive.format == format else {
            throw NotesArchiveError.invalidArchive
        }

        let replacements = try AttachmentArchive.restore(archive.attachments)
        let notes = archive.notes.map { note in
            var restored = note
            for (original, restoredURL) in replacements {
                restored.text = restored.text.replacingOccurrences(of: original, with: restoredURL)
            }
            return restored
        }

        archive.preferences.restore()

        let summary = NotesArchiveSummary(
            noteCount: notes.count,
            folderCount: archive.folders.count,
            attachmentCount: archive.attachments.count
        )
        return NotesArchiveImport(notes: notes, folders: archive.folders, summary: summary)
    }

    private static func archive(notes: [Note], folders: [Folder]) throws -> NotesArchive {
        NotesArchive(
            schemaVersion: schemaVersion,
            format: format,
            exportedAt: Date(),
            app: ArchiveAppInfo.current(),
            notes: notes,
            folders: folders,
            preferences: PreferencesArchive.current(),
            attachments: try AttachmentArchive.collect()
        )
    }

    static func importArchive(from url: URL) throws -> NotesArchiveImport {
        let data = try Data(contentsOf: url)
        return try importArchive(from: data)
    }

    private static var archiveEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    private static var archiveDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private struct NotesArchive: Codable {
    var schemaVersion: Int
    var format: String
    var exportedAt: Date
    var app: ArchiveAppInfo
    var notes: [Note]
    var folders: [Folder]
    var preferences: PreferencesArchive
    var attachments: [AttachmentArchive]
}

private struct ArchiveAppInfo: Codable {
    var version: String
    var build: String

    static func current() -> ArchiveAppInfo {
        let info = Bundle.main.infoDictionary ?? [:]
        return ArchiveAppInfo(
            version: info["CFBundleShortVersionString"] as? String ?? "",
            build: info["CFBundleVersion"] as? String ?? ""
        )
    }
}

private struct PreferencesArchive: Codable {
    var standard: DefaultsDomainArchive?
    var appGroup: DefaultsDomainArchive?

    static func current() -> PreferencesArchive {
        AppPreferences.registerDefaults()
        UserDefaults.standard.synchronize()
        AppAccentColor.sharedDefaults?.synchronize()

        let standardName = Bundle.main.bundleIdentifier ?? "com.adriendonot.Vellem"
        var standardDomain = UserDefaults.standard.persistentDomain(forName: standardName) ?? [:]
        for key in standardPreferenceKeys {
            if let value = UserDefaults.standard.object(forKey: key) {
                standardDomain[key] = value
            }
        }

        var appGroupDomain = AppAccentColor.sharedDefaults?.persistentDomain(forName: AppGroup.identifier) ?? [:]
        if let sharedAccent = AppAccentColor.sharedDefaults?.string(forKey: AppAccentColor.storageKey) {
            appGroupDomain[AppAccentColor.storageKey] = sharedAccent
        }

        return PreferencesArchive(
            standard: DefaultsDomainArchive(name: standardName, domain: standardDomain),
            appGroup: DefaultsDomainArchive(name: AppGroup.identifier, domain: appGroupDomain)
        )
    }

    func restore() {
        standard?.restore(into: .standard)
        if let appGroupDefaults = AppAccentColor.sharedDefaults {
            appGroup?.restore(into: appGroupDefaults)
        }

        if let rawAccent = UserDefaults.standard.string(forKey: AppAccentColor.storageKey) {
            AppAccentColor.sharedDefaults?.set(rawAccent, forKey: AppAccentColor.storageKey)
        }

        UserDefaults.standard.synchronize()
        AppAccentColor.sharedDefaults?.synchronize()
    }

    private static let standardPreferenceKeys = [
        AppPreferences.quickCaptureKeyCodeKey,
        AppPreferences.quickCaptureModifiersKey,
        AppPreferences.showMenuBarExtraKey,
        AppPreferences.showDockIconKey,
        AppPreferences.hasCompletedOnboardingKey,
        AppPreferences.colorSidebarKey,
        AppPreferences.colorTopBarKey,
        AppPreferences.trueTransparentSidebarKey,
        AppAccentColor.storageKey,
        "SUEnableAutomaticChecks",
        "SUAutomaticallyUpdate",
        "quickCaptureFloatsAboveOtherWindows"
    ]
}

private struct DefaultsDomainArchive: Codable {
    var name: String
    var propertyListBase64: String

    init?(name: String, domain: [String: Any]) {
        guard !domain.isEmpty,
              let data = try? PropertyListSerialization.data(
                fromPropertyList: domain,
                format: .binary,
                options: 0
              ) else {
            return nil
        }

        self.name = name
        self.propertyListBase64 = data.base64EncodedString()
    }

    func restore(into defaults: UserDefaults) {
        guard let data = Data(base64Encoded: propertyListBase64),
              let domain = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ) as? [String: Any] else {
            return
        }

        for (key, value) in domain {
            defaults.set(value, forKey: key)
        }
    }
}

private struct AttachmentArchive: Codable {
    var relativePath: String
    var originalURL: String
    var dataBase64: String

    static func collect() throws -> [AttachmentArchive] {
        let root = AppGroup.attachmentsURL
        guard FileManager.default.fileExists(atPath: root.path),
              let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        var attachments: [AttachmentArchive] = []
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }

            let relativePath = fileURL.path.replacingOccurrences(
                of: root.path + "/",
                with: ""
            )
            let data = try Data(contentsOf: fileURL)
            attachments.append(
                AttachmentArchive(
                    relativePath: relativePath,
                    originalURL: fileURL.absoluteString,
                    dataBase64: data.base64EncodedString()
                )
            )
        }

        return attachments.sorted { $0.relativePath < $1.relativePath }
    }

    static func restore(_ attachments: [AttachmentArchive]) throws -> [String: String] {
        guard !attachments.isEmpty else { return [:] }

        try FileManager.default.createDirectory(
            at: AppGroup.attachmentsURL,
            withIntermediateDirectories: true
        )

        var replacements: [String: String] = [:]
        for attachment in attachments {
            let destination = try restoredURL(for: attachment.relativePath)
            guard let data = Data(base64Encoded: attachment.dataBase64) else {
                throw NotesArchiveError.invalidAttachmentData(attachment.relativePath)
            }

            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: destination, options: [.atomic])
            replacements[attachment.originalURL] = destination.absoluteString
        }

        return replacements
    }

    private static func restoredURL(for relativePath: String) throws -> URL {
        let parts = relativePath
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }

        guard !parts.isEmpty else {
            throw NotesArchiveError.invalidAttachmentPath(relativePath)
        }

        return parts.reduce(AppGroup.attachmentsURL) { url, part in
            url.appending(path: part)
        }
    }
}
