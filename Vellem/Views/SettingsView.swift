import SwiftUI

struct SettingsView: View {
    @AppStorage(AppPreferences.quickCaptureKeyCodeKey) private var keyCode = Int(AppPreferences.defaultQuickCaptureKeyCode)
    @AppStorage(AppPreferences.quickCaptureModifiersKey) private var modifiers = Int(AppPreferences.defaultQuickCaptureModifiers)
    @AppStorage(AppPreferences.showMenuBarExtraKey) private var showMenuBarExtra = true
    @AppStorage(AppPreferences.showDockIconKey) private var showDockIcon = true
    @AppStorage(AppPreferences.colorSidebarKey) private var colorSidebar = true
    @AppStorage(AppPreferences.colorTopBarKey) private var colorTopBar = true
    @AppStorage(AppAccentColor.storageKey) private var accentRaw = AppAccentColor.defaultValue.rawValue
    @AppStorage("SUEnableAutomaticChecks") private var autoCheckUpdates = true
    @AppStorage("SUAutomaticallyUpdate") private var autoDownloadUpdates = false
    @ObservedObject private var updates = UpdateController.shared

    private var selectedAccent: AppAccentColor {
        AppAccentColor(rawValue: accentRaw) ?? .yellow
    }

    var body: some View {
        TabView {
            captureSettings
                .tabItem {
                    Label("Capture", systemImage: "square.and.pencil")
                }

            appearanceSettings
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }

            updateSettings
                .tabItem {
                    Label("Updates", systemImage: "arrow.triangle.2.circlepath")
                }

            appSettings
                .tabItem {
                    Label("App", systemImage: "macwindow")
                }
        }
        .padding(22)
        .frame(minWidth: 560, idealWidth: 560, maxWidth: 560, minHeight: 360)
        .onChange(of: showDockIcon) { _, newValue in
            if !newValue {
                showMenuBarExtra = true
            }
        }
    }

    private var captureSettings: some View {
        SettingsPane(
            title: "Quick Capture",
            subtitle: "Control how fast notes get into Vellem."
        ) {
            SettingsCard {
                LabeledContent("Shortcut") {
                    ShortcutRecorderView(keyCode: $keyCode, modifiers: $modifiers)
                }
            }
        }
    }

    private var appearanceSettings: some View {
        SettingsPane(
            title: "Appearance",
            subtitle: "Choose the color used across Vellem and Quick Capture."
        ) {
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("App color")
                        .font(.headline)

                    HStack(spacing: 12) {
                        ForEach(AppAccentColor.allCases) { color in
                            AccentSwatch(
                                color: color,
                                isSelected: color == selectedAccent
                            ) {
                                selectAccent(color)
                            }
                        }
                    }

                    Divider()

                    Toggle("Color sidebar", isOn: $colorSidebar)

                    Toggle("Color top bar", isOn: $colorTopBar)
                }
            }
        }
    }

    private var updateSettings: some View {
        SettingsPane(
            title: "Updates",
            subtitle: "Keep Vellem fresh without thinking about it."
        ) {
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Check for updates automatically", isOn: $autoCheckUpdates)

                    Toggle("Download and install updates automatically", isOn: $autoDownloadUpdates)
                        .disabled(!autoCheckUpdates)

                    Divider()

                    HStack {
                        Button("Check now…") {
                            updates.checkForUpdates()
                        }
                        .disabled(!updates.canCheckForUpdates)

                        Spacer()

                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var appSettings: some View {
        SettingsPane(
            title: "App",
            subtitle: "Set how Vellem appears on your Mac."
        ) {
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Show in menu bar", isOn: menuBarExtraBinding)
                        .disabled(!showDockIcon)

                    Toggle("Show Dock icon", isOn: $showDockIcon)

                    Divider()

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

private struct SettingsPane<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.weight(.semibold))

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            content

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
            )
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
