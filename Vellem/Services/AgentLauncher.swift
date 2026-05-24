import AppKit
import Foundation

enum AgentApp {
    case claude
    case codex

    var bundleIdentifier: String {
        switch self {
        case .claude: "com.anthropic.claudefordesktop"
        case .codex: "com.openai.codex"
        }
    }

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        }
    }

    var urlScheme: String {
        switch self {
        case .claude: "claude://"
        case .codex: "codex://"
        }
    }
}

enum AgentLauncher {
    static func send(prompt: String, to app: AgentApp) {
        copyToPasteboard(prompt)
        activate(app) {
            pasteIntoNewConversation(for: app)
        }
    }

    private static func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private static func activate(_ app: AgentApp, completion: @Sendable @escaping () -> Void) {
        let wasRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == app.bundleIdentifier }
        let delay: TimeInterval = wasRunning ? 0.8 : 2.0

        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    completion()
                }
            }
            return
        }

        if let url = URL(string: app.urlScheme) {
            NSWorkspace.shared.open(url)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                completion()
            }
        }
    }

    private static func pasteIntoNewConversation(for app: AgentApp) {
        let source = """
        tell application id "\(app.bundleIdentifier)" to activate
        delay 0.5
        tell application "System Events"
            tell process "\(app.processName)"
                set frontmost to true
            end tell
            delay 0.2
            keystroke "n" using command down
            delay 0.7
            keystroke "v" using command down
        end tell
        """
        guard let script = NSAppleScript(source: source) else { return }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error {
            NSLog("AgentLauncher AppleScript error: \(error)")
        }
    }
}

private extension AgentApp {
    var processName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        }
    }
}
