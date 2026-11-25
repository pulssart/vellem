import AppKit
import SwiftUI

enum KnownTool: String, CaseIterable, Identifiable, Hashable {
    case slack
    case gmail
    case mail
    case calendar
    case googleDocs
    case googleSheets
    case googleSlides
    case granola
    case linear
    case figma
    case notion
    case github

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .slack: "Slack"
        case .gmail: "Gmail"
        case .mail: "Mail"
        case .calendar: "Calendar"
        case .googleDocs: "Google Docs"
        case .googleSheets: "Google Sheets"
        case .googleSlides: "Google Slides"
        case .granola: "Granola"
        case .linear: "Linear"
        case .figma: "Figma"
        case .notion: "Notion"
        case .github: "GitHub"
        }
    }

    var appPaths: [String] {
        switch self {
        case .slack: ["/Applications/Slack.app"]
        case .granola: ["/Applications/Granola.app"]
        case .linear: ["/Applications/Linear.app"]
        case .figma: ["/Applications/Figma.app", "/Applications/Figma Beta.app"]
        case .notion: ["/Applications/Notion.app"]
        case .github: ["/Applications/GitHub Desktop.app"]
        case .gmail, .mail, .calendar, .googleDocs, .googleSheets, .googleSlides: []
        }
    }

    var bundledAssetName: String? {
        switch self {
        case .slack: "Slack"
        case .gmail: "Gmail"
        case .calendar: "GoogleCalendar"
        case .notion: "Notion"
        default: nil
        }
    }

    @MainActor
    var realIcon: NSImage? {
        for path in appPaths {
            if FileManager.default.fileExists(atPath: path) {
                return NSWorkspace.shared.icon(forFile: path)
            }
        }
        if let name = bundledAssetName, let image = NSImage(named: name) {
            return image
        }
        return nil
    }

    var systemImageFallback: String {
        switch self {
        case .slack: "number"
        case .gmail: "envelope.fill"
        case .mail: "envelope.fill"
        case .calendar: "calendar"
        case .googleDocs: "doc.text.fill"
        case .googleSheets: "tablecells.fill"
        case .googleSlides: "rectangle.on.rectangle.fill"
        case .granola: "waveform"
        case .linear: "l.square.fill"
        case .figma: "f.cursive"
        case .notion: "n.square.fill"
        case .github: "chevron.left.forwardslash.chevron.right"
        }
    }
}

struct ToolBadge: View {
    let tool: KnownTool
    var size: CGFloat = 16

    var body: some View {
        Group {
            if let icon = tool.realIcon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .saturation(0)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .fill(InboxPalette.ink)
                    Image(systemName: tool.systemImageFallback)
                        .font(.system(size: size * 0.60, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .help(tool.displayName)
    }
}

struct ToolBadgeRow: View {
    let tools: [KnownTool]
    var size: CGFloat = 16

    var body: some View {
        if !tools.isEmpty {
            HStack(spacing: 4) {
                ForEach(tools) { tool in
                    ToolBadge(tool: tool, size: size)
                }
            }
        }
    }
}
