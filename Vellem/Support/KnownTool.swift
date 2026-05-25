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
        case .gmail: "Gmail"
        case .calendar: "GoogleCalendar"
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

    var brandColor: Color {
        switch self {
        case .slack:    Color(red: 0.29, green: 0.08, blue: 0.29)
        case .gmail:    Color(red: 0.92, green: 0.26, blue: 0.21) // Gmail red
        case .mail:     Color(red: 0.00, green: 0.48, blue: 1.00)
        case .calendar: Color(red: 0.10, green: 0.45, blue: 0.91) // Google Calendar blue
        case .googleDocs: Color(red: 0.10, green: 0.45, blue: 0.91)
        case .googleSheets: Color(red: 0.20, green: 0.66, blue: 0.33)
        case .googleSlides: Color(red: 0.96, green: 0.62, blue: 0.04)
        case .granola:  Color(red: 1.00, green: 0.42, blue: 0.21)
        case .linear:   Color(red: 0.37, green: 0.42, blue: 0.82)
        case .figma:    Color(red: 0.95, green: 0.31, blue: 0.12)
        case .notion:   Color(red: 0.10, green: 0.10, blue: 0.10)
        case .github:   Color(red: 0.13, green: 0.13, blue: 0.15)
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
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .fill(tool.brandColor)
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
