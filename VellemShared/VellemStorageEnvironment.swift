import Foundation

enum VellemStorageEnvironment {
    static var isolatedDirectory: URL? {
        #if DEBUG
        guard let path = ProcessInfo.processInfo.environment["VELLEM_TEST_DIRECTORY"], !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
        #else
        return nil
        #endif
    }
}
