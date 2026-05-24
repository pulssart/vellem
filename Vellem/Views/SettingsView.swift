import SwiftUI

struct SettingsView: View {
    @AppStorage(AppPreferences.quickCaptureKeyCodeKey) private var keyCode = Int(AppPreferences.defaultQuickCaptureKeyCode)
    @AppStorage(AppPreferences.quickCaptureModifiersKey) private var modifiers = Int(AppPreferences.defaultQuickCaptureModifiers)
    @AppStorage(AppPreferences.showMenuBarExtraKey) private var showMenuBarExtra = true
    @AppStorage(AppPreferences.showDockIconKey) private var showDockIcon = true

    var body: some View {
        Form {
            Section("Quick Note") {
                LabeledContent("Shortcut") {
                    ShortcutRecorderView(keyCode: $keyCode, modifiers: $modifiers)
                }
            }

            Section("App") {
                Toggle("Show in menu bar", isOn: menuBarExtraBinding)
                    .disabled(!showDockIcon)
                Toggle("Show Dock icon", isOn: $showDockIcon)

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

    private var menuBarExtraBinding: Binding<Bool> {
        Binding {
            showMenuBarExtra || !showDockIcon
        } set: { newValue in
            showMenuBarExtra = showDockIcon ? newValue : true
        }
    }
}
