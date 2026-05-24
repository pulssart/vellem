import SwiftUI

struct SettingsView: View {
    @AppStorage(AppPreferences.quickCaptureKeyCodeKey) private var keyCode = Int(AppPreferences.defaultQuickCaptureKeyCode)
    @AppStorage(AppPreferences.quickCaptureModifiersKey) private var modifiers = Int(AppPreferences.defaultQuickCaptureModifiers)
    @AppStorage(AppPreferences.showMenuBarExtraKey) private var showMenuBarExtra = true
    @AppStorage(AppPreferences.showDockIconKey) private var showDockIcon = true
    @AppStorage(AppAccentColor.storageKey) private var accentRaw = AppAccentColor.defaultValue.rawValue
    @AppStorage("SUEnableAutomaticChecks") private var autoCheckUpdates = true
    @AppStorage("SUAutomaticallyUpdate") private var autoDownloadUpdates = false
    @ObservedObject private var updates = UpdateController.shared

    private var selectedAccent: AppAccentColor {
        AppAccentColor(rawValue: accentRaw) ?? .yellow
    }

    var body: some View {
        Form {
            Section("Quick Note") {
                LabeledContent("Shortcut") {
                    ShortcutRecorderView(keyCode: $keyCode, modifiers: $modifiers)
                }
            }

            Section("Appearance") {
                LabeledContent("App color") {
                    HStack(spacing: 10) {
                        ForEach(AppAccentColor.allCases) { color in
                            AccentSwatch(
                                color: color,
                                isSelected: color == selectedAccent
                            ) {
                                selectAccent(color)
                            }
                        }
                    }
                }
            }

            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $autoCheckUpdates)
                Toggle("Download and install updates automatically", isOn: $autoDownloadUpdates)
                    .disabled(!autoCheckUpdates)
                HStack {
                    Button("Check now…") {
                        updates.checkForUpdates()
                    }
                    .disabled(!updates.canCheckForUpdates)
                    Spacer()
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("App") {
                Toggle("Show in menu bar", isOn: menuBarExtraBinding)
                    .disabled(!showDockIcon)
                Toggle("Show Dock icon", isOn: $showDockIcon)
                Button("Show onboarding") {
                    NotificationCenter.default.post(name: .vellemShowOnboarding, object: nil)
                    NSApp.activate(ignoringOtherApps: true)
                }

                if !showDockIcon {
                    Text("The menu bar icon stays on so you can still open settings and quit the app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(width: 460)
        .onChange(of: showDockIcon) { _, newValue in
            if !newValue {
                showMenuBarExtra = true
            }
        }
    }

    private func selectAccent(_ color: AppAccentColor) {
        accentRaw = color.rawValue
        AppAccentColor.sharedDefaults?.set(color.rawValue, forKey: AppAccentColor.storageKey)
        WidgetReloader.reload()
    }

    private var menuBarExtraBinding: Binding<Bool> {
        Binding {
            showMenuBarExtra || !showDockIcon
        } set: { newValue in
            showMenuBarExtra = showDockIcon ? newValue : true
        }
    }
}

private struct AccentSwatch: View {
    let color: AppAccentColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color.color)
                    .frame(width: 22, height: 22)
                if isSelected {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.85), lineWidth: 2)
                        .frame(width: 26, height: 26)
                }
            }
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(color.displayName)
    }
}
