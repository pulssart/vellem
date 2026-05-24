import AppKit
import SwiftUI

enum AppAccentColor: String, CaseIterable, Identifiable {
    case yellow
    case orange
    case red
    case pink
    case purple
    case blue
    case green

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .yellow: "Yellow"
        case .orange: "Orange"
        case .red: "Red"
        case .pink: "Pink"
        case .purple: "Purple"
        case .blue: "Blue"
        case .green: "Green"
        }
    }

    var nsColor: NSColor {
        switch self {
        case .yellow: .systemYellow
        case .orange: .systemOrange
        case .red: .systemRed
        case .pink: .systemPink
        case .purple: .systemPurple
        case .blue: .systemBlue
        case .green: .systemGreen
        }
    }

    var color: Color { Color(nsColor: nsColor) }

    static let storageKey = "appAccentColor"
    static let defaultValue: AppAccentColor = .yellow

    static var current: AppAccentColor {
        let raw = sharedDefaults?.string(forKey: storageKey)
            ?? UserDefaults.standard.string(forKey: storageKey)
            ?? defaultValue.rawValue
        return AppAccentColor(rawValue: raw) ?? defaultValue
    }

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "MKAFV9VL9V.com.adriendonot.Vellem")
    }
}

extension NSColor {
    static var appAccent: NSColor { AppAccentColor.current.nsColor }
}

extension Color {
    static var appAccent: Color { AppAccentColor.current.color }
}

@propertyWrapper
struct AppAccent: DynamicProperty {
    @AppStorage(AppAccentColor.storageKey) private var raw: String = AppAccentColor.defaultValue.rawValue
    var wrappedValue: AppAccentColor {
        AppAccentColor(rawValue: raw) ?? AppAccentColor.defaultValue
    }
}
