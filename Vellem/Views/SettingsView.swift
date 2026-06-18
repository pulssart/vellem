import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: NotesStore
    @AppStorage(AppPreferences.quickCaptureKeyCodeKey) private var keyCode = Int(AppPreferences.defaultQuickCaptureKeyCode)
    @AppStorage(AppPreferences.quickCaptureModifiersKey) private var modifiers = Int(AppPreferences.defaultQuickCaptureModifiers)
    @AppStorage(AppPreferences.showMenuBarExtraKey) private var showMenuBarExtra = true
    @AppStorage(AppPreferences.showDockIconKey) private var showDockIcon = true
    @AppStorage(AppPreferences.colorSidebarKey) private var colorSidebar = true
    @AppStorage(AppPreferences.colorTopBarKey) private var colorTopBar = true
    @AppStorage(AppPreferences.trueTransparentSidebarKey) private var trueTransparentSidebar = false
    @AppStorage(AppAccentColor.storageKey) private var accentRaw = AppAccentColor.defaultValue.rawValue
    @AppStorage("SUEnableAutomaticChecks") private var autoCheckUpdates = true
    @AppStorage("SUAutomaticallyUpdate") private var autoDownloadUpdates = false
    @ObservedObject private var updates = UpdateController.shared
    @State private var archiveStatus: ArchiveStatus?
    @State private var isArchiveWorking = false
    @State private var pendingImportData: Data?
    @State private var activePanel: NSSavePanel?
    @State private var showsImportConfirmation = false

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

            dataSettings
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }

            appSettings
                .tabItem {
                    Label("App", systemImage: "macwindow")
                }
        }
        .padding(22)
        .frame(minWidth: 600, idealWidth: 600, maxWidth: 600, minHeight: 420)
        .onChange(of: showDockIcon) { _, newValue in
            if !newValue {
                showMenuBarExtra = true
            }
        }
        .alert("Replace your Vellem library?", isPresented: $showsImportConfirmation) {
            Button("Import", role: .destructive) {
                confirmPendingImport()
            }
            Button("Cancel", role: .cancel) {
                pendingImportData = nil
            }
        } message: {
            Text("This imports notes, folders, attachments, and preferences from the JSON file.")
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

                    Toggle("True transparent sidebar", isOn: $trueTransparentSidebar)
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

    private var dataSettings: some View {
        SettingsPane(
            title: "Data",
            subtitle: "Back up or restore your Vellem library."
        ) {
            SettingsCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Export")
                                .font(.headline)

                            Text("\(store.notes.count) notes, \(store.folders.count) folders")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Export JSON...") {
                            exportArchive()
                        }
                        .disabled(isArchiveWorking)
                    }

                    Divider()

                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Import")
                                .font(.headline)

                            Text("Replaces notes, folders, attachments, and preferences.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Import JSON...") {
                            importArchive()
                        }
                        .disabled(isArchiveWorking)
                    }

                    if let archiveStatus {
                        Divider()

                        Label(archiveStatus.message, systemImage: archiveStatus.systemImage)
                            .font(.caption)
                            .foregroundStyle(archiveStatus.isError ? .red : .secondary)
                            .lineLimit(2)
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

    private func exportArchive() {
        isArchiveWorking = true

        do {
            let archive = try NotesArchiveService.archiveData(
                notes: store.notes,
                folders: store.folders
            )
            presentExportPanel(data: archive.data, summary: archive.summary)
        } catch {
            isArchiveWorking = false
            archiveStatus = .failure(error.localizedDescription)
        }
    }

    private func importArchive() {
        archiveStatus = nil
        isArchiveWorking = true

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        present(panel) { response in
            defer {
                isArchiveWorking = false
                activePanel = nil
            }

            guard response == .OK,
                  let url = panel.url else {
                return
            }

            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                pendingImportData = try Data(contentsOf: url)
                showsImportConfirmation = true
            } catch {
                archiveStatus = .failure(error.localizedDescription)
            }
        }
    }

    private func presentExportPanel(data: Data, summary: NotesArchiveSummary) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = defaultArchiveFileName

        present(panel) { response in
            defer {
                isArchiveWorking = false
                activePanel = nil
            }

            guard response == .OK,
                  let url = panel.url else {
                return
            }

            do {
                try data.write(to: url, options: [.atomic])
                archiveStatus = .success("Exported \(summary.noteCount) notes, \(summary.folderCount) folders, \(summary.attachmentCount) attachments.")
            } catch {
                archiveStatus = .failure(error.localizedDescription)
            }
        }
    }

    private func present(_ panel: NSSavePanel, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        activePanel = panel
        panel.level = .modalPanel
        NSApp.activate(ignoringOtherApps: true)
        panel.begin(completionHandler: completion)
    }

    private func confirmPendingImport() {
        guard let data = pendingImportData else { return }
        pendingImportData = nil
        isArchiveWorking = true
        defer { isArchiveWorking = false }

        do {
            let imported = try NotesArchiveService.importArchive(from: data)
            try store.replaceLibrary(notes: imported.notes, folders: imported.folders)
            AppPreferences.registerDefaults()
            AppDelegate.applyDockIconPreference(showDockIcon: UserDefaults.standard.bool(forKey: AppPreferences.showDockIconKey))
            NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: UserDefaults.standard)
            WidgetReloader.reload()
            archiveStatus = .success("Imported \(imported.summary.noteCount) notes, \(imported.summary.folderCount) folders, \(imported.summary.attachmentCount) attachments.")
        } catch {
            archiveStatus = .failure(error.localizedDescription)
        }
    }

    private var defaultArchiveFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "Vellem Library \(formatter.string(from: Date())).json"
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

private struct ArchiveStatus {
    let message: String
    let isError: Bool

    var systemImage: String {
        isError ? "exclamationmark.triangle" : "checkmark.circle"
    }

    static func success(_ message: String) -> ArchiveStatus {
        ArchiveStatus(message: message, isError: false)
    }

    static func failure(_ message: String) -> ArchiveStatus {
        ArchiveStatus(message: message, isError: true)
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
