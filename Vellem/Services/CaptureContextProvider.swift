import AppKit
import Foundation

@MainActor
enum CaptureContextProvider {
    private static var lastExternalApplication: RunningApplicationSnapshot?
    private static var lastExternalSource: CaptureSource?

    static func currentSource() -> CaptureSource {
        if let application = externalFrontmostApplication() {
            return source(for: application)
        }

        if let lastExternalApplication {
            let source = source(for: lastExternalApplication)
            if source.url != nil {
                return source
            }
        }

        return lastExternalSource ?? CaptureSource(appName: nil, url: nil)
    }

    static func rememberActiveApplication(_ application: NSRunningApplication) {
        guard application.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return
        }

        let snapshot = RunningApplicationSnapshot(
            localizedName: application.localizedName,
            bundleIdentifier: application.bundleIdentifier
        )
        lastExternalApplication = snapshot
        lastExternalSource = source(for: snapshot)
    }

    private static func externalFrontmostApplication() -> RunningApplicationSnapshot? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }

        return RunningApplicationSnapshot(
            localizedName: application.localizedName,
            bundleIdentifier: application.bundleIdentifier
        )
    }

    private static func source(for application: RunningApplicationSnapshot) -> CaptureSource {
        let source = CaptureSource(appName: application.localizedName, url: browserURL(for: application.bundleIdentifier))
        if source.url != nil {
            lastExternalSource = source
        }
        return source
    }

    private static func browserURL(for bundleIdentifier: String?) -> URL? {
        guard let bundleIdentifier else { return nil }

        let script: String?
        switch bundleIdentifier {
        case "com.apple.Safari":
            script = "tell application \"Safari\" to get URL of front document"
        case "com.google.Chrome",
             "com.google.Chrome.canary",
             "com.microsoft.edgemac",
             "com.brave.Browser",
             "company.thebrowser.Browser",
             "company.thebrowser.dia",
             "com.operasoftware.Opera",
             "com.vivaldi.Vivaldi":
            script = "tell application id \"\(bundleIdentifier)\" to get URL of active tab of front window"
        default:
            script = nil
        }

        guard let script,
              let appleScript = NSAppleScript(source: script) else {
            return nil
        }

        var error: NSDictionary?
        let output = appleScript.executeAndReturnError(&error)
        guard error == nil,
              let value = output.stringValue,
              let url = URL(string: value) else {
            return nil
        }

        return url
    }
}

private struct RunningApplicationSnapshot {
    var localizedName: String?
    var bundleIdentifier: String?
}
