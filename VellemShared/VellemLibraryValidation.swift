import Foundation

enum VellemLibraryValidation {
    static func uniqueIDs<T: Identifiable>(_ values: [T], kind: String) throws -> [T] {
        guard Set(values.map(\.id)).count == values.count else {
            throw NSError(domain: "VellemLibrary", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "The \(kind) file contains duplicate identifiers."
            ])
        }
        return values
    }
}
