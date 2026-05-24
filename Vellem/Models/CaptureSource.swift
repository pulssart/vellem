import Foundation

struct CaptureSource: Codable, Hashable {
    var appName: String?
    var url: URL?

    var description: String? {
        switch (appName, url) {
        case let (appName?, url?):
            "\(appName), \(url.absoluteString)"
        case let (appName?, nil):
            appName
        case let (nil, url?):
            url.absoluteString
        case (nil, nil):
            nil
        }
    }
}
