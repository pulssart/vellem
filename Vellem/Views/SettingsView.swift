import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: NotesStore
    @AppStorage(AppPreferences.settingsTabKey) private var selectedTab = "Agents"
    @AppStorage(AppPreferences.showMenuBarExtraKey) private var showMenuBarExtra = true
    @AppStorage(AppPreferences.showDockIconKey) private var showDockIcon = true
    @AppStorage(AppPreferences.hiddenInboxAgentsKey) private var hiddenAgents = HiddenInboxAgents()
    @AppStorage("SUEnableAutomaticChecks") private var autoCheckUpdates = true
    @AppStorage("SUAutomaticallyUpdate") private var autoDownloadUpdates = false
    @ObservedObject private var updates = UpdateController.shared
    @State private var archiveStatus: ArchiveStatus?
    @State private var isArchiveWorking = false
    @State private var pendingImportData: Data?
    @State private var activePanel: NSSavePanel?
    @State private var showsImportConfirmation = false
    @State private var showsInboxGuide = false

    private var tabSelection: Binding<String> {
        Binding {
            ["Agents", "Updates", "Data", "App"].contains(selectedTab) ? selectedTab : "Agents"
        } set: { selectedTab = $0 }
    }

    var body: some View {
        TabView(selection: tabSelection) {
            agentSettings
                .tabItem {
                    Label("Agents", systemImage: "terminal")
                }.tag("Agents")

            updateSettings
                .tabItem {
                    Label("Updates", systemImage: "arrow.triangle.2.circlepath")
                }.tag("Updates")

            dataSettings
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }.tag("Data")

            appSettings
                .tabItem {
                    Label("App", systemImage: "macwindow")
                }.tag("App")
        }
        .padding(22)
        .frame(minWidth: 600, idealWidth: 600, maxWidth: 600, minHeight: 420)
        .sheet(isPresented: $showsInboxGuide) {
            OnboardingView(isPresented: $showsInboxGuide) { selectedTab = "Agents" }
        }
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

    private var agentSettings: some View {
        ScrollView {
            SettingsPane(
                title: "Sidebar agents",
                subtitle: "Hidden agents still deliver messages to All inboxes."
            ) {
                SettingsCard {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 32), GridItem(.flexible())], spacing: 12) {
                        ForEach(InboxAgent.allCases, id: \.self) { agent in
                            Toggle(isOn: Binding {
                                hiddenAgents.isVisible(agent)
                            } set: { visible in
                                hiddenAgents.setVisible(visible, for: agent)
                            }) {
                                HStack(spacing: 9) {
                                    AgentMark(agent: agent, size: 24)
                                    Text(agent.rawValue)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .accessibilityLabel(agent.rawValue)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("Agent connections").font(.headline)
                    SettingsCard { AgentConnectionView() }
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(minHeight: 420)
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

                            Text("Replaces notes and folders, restores attachments and preferences.")
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
                            .foregroundStyle(archiveStatus.isError ? Color.primary : Color.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    private var appSettings: some View {
        SettingsPane(
            title: "Vellem",
            subtitle: "Set how Vellem appears on your Mac.",
            showsAppIcon: true
        ) {
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    LanguagePicker()
                    Divider()
                    Toggle("Show in menu bar", isOn: menuBarExtraBinding)
                        .disabled(!showDockIcon)

                    Toggle("Show Dock icon", isOn: $showDockIcon)

                    Divider()

                    Button("Inbox guide…") { showsInboxGuide = true }

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
                archiveStatus = .success(VellemLanguage.format("Exported %lld notes, %lld folders, %lld attachments.", summary.noteCount, summary.folderCount, summary.attachmentCount))
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
            imported.restorePreferences()
            AppPreferences.registerDefaults()
            AppDelegate.applyDockIconPreference(showDockIcon: UserDefaults.standard.bool(forKey: AppPreferences.showDockIconKey))
            NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: UserDefaults.standard)
            WidgetReloader.reload()
            archiveStatus = .success(VellemLanguage.format("Imported %lld notes, %lld folders, %lld attachments.", imported.summary.noteCount, imported.summary.folderCount, imported.summary.attachmentCount))
        } catch {
            archiveStatus = .failure(error.localizedDescription)
        }
    }

    private var defaultArchiveFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "Vellem Library \(formatter.string(from: Date())).json"
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
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var showsAppIcon = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                if showsAppIcon {
                    Image(nsImage: NSApp.applicationIconImage).resizable()
                        .frame(width: 52, height: 52).accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title2.weight(.semibold))
                    Text(subtitle).font(.callout).foregroundStyle(.secondary)
                }
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
