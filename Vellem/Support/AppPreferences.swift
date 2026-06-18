import Carbon
import Foundation

enum AppPreferences {
    static let quickCaptureKeyCodeKey = "quickCaptureShortcutKeyCode"
    static let quickCaptureModifiersKey = "quickCaptureShortcutModifiers"
    static let showMenuBarExtraKey = "showMenuBarExtra"
    static let showDockIconKey = "showDockIcon"
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    static let colorSidebarKey = "colorSidebar"
    static let colorTopBarKey = "colorTopBar"
    static let trueTransparentSidebarKey = "trueTransparentSidebar"

    static let defaultQuickCaptureKeyCode = UInt32(kVK_ANSI_N)
    static let defaultQuickCaptureModifiers = UInt32(controlKey | optionKey)

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            quickCaptureKeyCodeKey: Int(defaultQuickCaptureKeyCode),
            quickCaptureModifiersKey: Int(defaultQuickCaptureModifiers),
            showMenuBarExtraKey: true,
            showDockIconKey: true,
            hasCompletedOnboardingKey: false,
            colorSidebarKey: true,
            colorTopBarKey: true,
            trueTransparentSidebarKey: false,
            AppAccentColor.storageKey: AppAccentColor.defaultValue.rawValue
        ])

        if let shared = AppAccentColor.sharedDefaults {
            let current = UserDefaults.standard.string(forKey: AppAccentColor.storageKey)
                ?? AppAccentColor.defaultValue.rawValue
            shared.set(current, forKey: AppAccentColor.storageKey)
        }
    }

    static var quickCaptureShortcut: AppShortcut {
        AppShortcut(
            keyCode: UInt32(UserDefaults.standard.integer(forKey: quickCaptureKeyCodeKey)),
            modifiers: UInt32(UserDefaults.standard.integer(forKey: quickCaptureModifiersKey))
        )
        .normalized
    }
}

struct AppShortcut: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    var normalized: AppShortcut {
        guard keyCode != 0 || modifiers != 0 else {
            return AppShortcut(
                keyCode: AppPreferences.defaultQuickCaptureKeyCode,
                modifiers: AppPreferences.defaultQuickCaptureModifiers
            )
        }
        return self
    }
}
