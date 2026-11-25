import Foundation

/// Only the originating Mac resolves report IDs to local CLI sessions.
struct MobileAction: Codable, Identifiable, Equatable, Sendable {
    enum Kind: Codable, Equatable, Sendable {
        case read(note: UUID)
        case createFolder(id: UUID, name: String, agent: String)
        case move(note: UUID, folder: UUID?)
        case reply(note: UUID, text: String)
    }
    var id = UUID()
    var date = Date()
    let kind: Kind
}

struct MobileReceipt: Codable, Sendable {
    var error: String?
}

enum MobileMailboxFiles {
    static func requests(in root: URL) -> URL { root.appending(path: "MobileRequests", directoryHint: .isDirectory) }
    static func result(_ id: UUID, in root: URL) -> URL {
        root.appending(path: "MobileResults", directoryHint: .isDirectory).appending(path: id.uuidString + ".json")
    }
    static func submit(_ action: MobileAction, in root: URL) throws {
        let file = requests(in: root).appending(path: action.id.uuidString + ".json")
        guard !FileManager.default.fileExists(atPath: file.path) else { return }
        try write(action, to: file)
    }
    static func write<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try CloudMirrorStore.write(JSONEncoder().encode(value), to: url)
    }
    static func read<T: Decodable>(_ type: T.Type, from file: URL) throws -> T {
        try CloudMirrorStore.startDownloadingIfNeeded(file)
        return try JSONDecoder().decode(type, from: CloudMirrorStore.coordinatedRead(from: file))
    }
}
