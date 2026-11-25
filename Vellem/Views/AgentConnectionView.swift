import AppKit
import SwiftUI

private enum ConnectionClient: String, CaseIterable, Identifiable {
    case codex = "Codex"
    case claude = "Claude Code"
    case gemini = "Gemini CLI"
    case grok = "Grok Build"
    case bot = "Grok Bot"
    case desktop = "Claude Desktop"

    var id: Self { self }

    var command: String {
        let path = Bundle.main.bundleURL.appending(path: "Contents/Resources/vellem-mcp").path
        let quoted = "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        switch self {
        case .codex: return "codex mcp add vellem -- " + quoted
        case .claude: return "claude mcp add --scope user --transport stdio vellem -- " + quoted
        case .gemini: return "gemini mcp add --scope user vellem " + quoted
        case .grok: return "grok mcp add vellem -- " + quoted
        case .bot: return quoted + " send --agent Grokbot --format markdown < output.md"
        case .desktop:
            let config = ["mcpServers": ["vellem": ["command": path]]]
            let data = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            return data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        }
    }

    var help: LocalizedStringKey {
        switch self {
        case .bot: "Ask your bot to run this on your Mac with the path to its output file. You can also pipe UTF-8 text into the same command."
        case .desktop: "Merge this entry into ~/Library/Application Support/Claude/claude_desktop_config.json, then restart Claude Desktop."
        default: "Paste the command in Terminal and press Return. Then open a new session in your agent."
        }
    }

    var usesCLI: Bool { self != .bot && self != .desktop }
}

struct AgentConnectionView: View {
    @State private var client = ConnectionClient.codex
    @State private var copied = false
    @State private var launchError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Client", selection: $client) {
                ForEach(ConnectionClient.allCases) { Text($0.rawValue).tag($0) }
            }.fixedSize()
            Text(client.help).font(.callout).foregroundStyle(.secondary)
            Text(verbatim: client.command)
                .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
            HStack {
                if client.usesCLI {
                    Button("Copy and open Terminal") {
                        copyCommand()
                        openTerminal()
                    }.buttonStyle(.borderedProminent)
                }
                Button(copied ? "Copied" : (client == .desktop ? "Copy configuration" : "Copy command")) {
                    copyCommand()
                }
            }
            if let launchError {
                Label(LocalizedStringKey(launchError), systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.primary)
            }
        }
        .onChange(of: client) { copied = false; launchError = nil }
    }

    private func copyCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(client.command, forType: .string)
        copied = true
        launchError = nil
    }

    private func openTerminal() {
        guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            launchError = "Command copied. Open a terminal and paste it to connect."
            return
        }
        NSWorkspace.shared.openApplication(at: terminal, configuration: .init()) { _, error in
            if error != nil {
                Task { @MainActor in launchError = "Command copied. Open a terminal and paste it to connect." }
            }
        }
    }
}
