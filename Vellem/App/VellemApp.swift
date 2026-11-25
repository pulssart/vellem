import SwiftUI
import UserNotifications

@main
struct VellemApp: App {
    @AppStorage(VellemLanguage.preferenceKey, store: VellemLanguage.defaults) private var language: VellemLanguage = .system
    @Environment(\.openWindow) private var openWindow

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = NotesStore()
    @AppStorage(AppPreferences.showMenuBarExtraKey) private var showMenuBarExtra = true
    @AppStorage(AppPreferences.showDockIconKey) private var showDockIcon = true
    @StateObject private var updateController = UpdateController.shared

    init() {
        AppPreferences.registerDefaults()
    }

    var body: some Scene {
        WindowGroup("Vellem", id: "main") {
            ContentView(store: store)
                .environment(\.locale, language.locale)
                .frame(minWidth: 830, minHeight: 560)
                .tint(InboxPalette.accent)
                .background(ExternalNoteEventBridge(store: store))
                .onOpenURL { url in
                    handle(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .vellemOpenNoteViewer)) { notification in
                    guard let noteID = notification.object as? Note.ID else { return }
                    store.viewerNoteID = noteID
                    openWindow(id: "note-viewer")
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .environment(\.locale, language.locale)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(after: .appInfo) {
                Button(VellemLanguage.text("Check for Updates…", locale: language.locale)) {
                    updateController.checkForUpdates()
                }
                .disabled(!updateController.canCheckForUpdates)
            }

            CommandGroup(replacing: .newItem) {
                Button(VellemLanguage.text("Open Today", locale: language.locale)) {
                    NotificationCenter.default.post(name: .vellemMailboxReset, object: nil)
                    store.selectToday()
                    showMainWindow()
                }
                .keyboardShortcut("d", modifiers: [.command, .option])
                .disabled(store.libraryUnavailable)

                Button(VellemLanguage.text("Show Vellem", locale: language.locale)) {
                    showMainWindow()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(after: .textEditing) {
                Button(VellemLanguage.text("Search Notes", locale: language.locale)) {
                    NotificationCenter.default.post(name: .vellemFocusSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command])
            }
        }

        MenuBarExtra("Vellem", image: "FoldMark", isInserted: menuBarExtraBinding) {
            Button(VellemLanguage.text("Open inbox", locale: language.locale), action: showInbox)
            if !store.notes.isEmpty {
                Section(VellemLanguage.text("Recent messages", locale: language.locale)) {
                    ForEach(store.notes.prefix(5)) { note in
                        Button(note.title) {
                            store.viewerNoteID = note.id
                            openWindow(id: "note-viewer")
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }
                }
            }
            Divider()
            SettingsLink { Text(verbatim: VellemLanguage.text("Settings…", locale: language.locale)) }
            Button(VellemLanguage.text("Quit Vellem", locale: language.locale)) { NSApp.terminate(nil) }
        }

        .environment(\.locale, language.locale)

        Window(Text(verbatim: VellemLanguage.text("View Note", locale: language.locale)), id: "note-viewer") {
            NoteViewerView(store: store)
                .environment(\.locale, language.locale)
                .tint(InboxPalette.accent)
        }
        .defaultSize(width: 560, height: 600)
        .windowResizability(.automatic)
        .environment(\.locale, language.locale)
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView(store: store)
                .environment(\.locale, language.locale)
                .tint(InboxPalette.accent)
        }
    }

    private func handle(_ url: URL) {
        guard url.scheme == "vellem" else { return }
        if url.host == "note",
           let idString = url.pathComponents.dropFirst().first,
           let uuid = UUID(uuidString: idString) {
            NotificationCenter.default.post(name: .vellemOpenNoteViewer, object: uuid)
            NSApp.activate(ignoringOtherApps: true)
        } else if url.host == "inbox" || url.host == "new" {
            showInbox()
        } else {
            showMainWindow()
        }
    }

    private func showInbox() {
        store.selectInbox()
        NotificationCenter.default.post(name: .vellemMailboxReset, object: nil)
        showMainWindow()
    }

    private func showMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NSApp.showVellemMainWindow()
        }
    }

    private var menuBarExtraBinding: Binding<Bool> {
        Binding {
            showMenuBarExtra || !showDockIcon
        } set: { isInserted in
            showMenuBarExtra = showDockIcon ? isInserted : true
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSUserNotificationCenterDelegate {
    private let mobileMailbox = MobileMailboxMonitor()
    private var observesPreferences = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if VellemStorageEnvironment.isolatedDirectory != nil,
           ProcessInfo.processInfo.environment["VELLEM_TEST_APPEARANCE"] == "dark" {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
        #endif
        AppPreferences.registerDefaults()
        Self.applyDockIconPreference(
            showDockIcon: UserDefaults.standard.bool(forKey: AppPreferences.showDockIconKey)
        )
        // Use the icon of the launched copy, including the user's Finder icon preference.
        let dockIcon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        dockIcon.size = NSSize(width: 512, height: 512)
        NSApp.applicationIconImage = dockIcon
        NSUserNotificationCenter.default.delegate = self
        if VellemStorageEnvironment.isolatedDirectory == nil {
            NoteNotifications.requestAuthorization(delegate: self)
        }
        observePreferenceChanges()
        mobileMailbox.start()

        #if DEBUG
        if VellemStorageEnvironment.isolatedDirectory != nil,
           ProcessInfo.processInfo.environment["VELLEM_TEST_BACKGROUND"] == "1" {
            return
        }
        #endif
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.showVellemMainWindow()
        }
    }

    private func observePreferenceChanges() {
        guard !observesPreferences else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        observesPreferences = true
    }

    @objc private func preferencesChanged(_ notification: Notification) {
        Self.applyDockIconPreference(
            showDockIcon: UserDefaults.standard.bool(forKey: AppPreferences.showDockIconKey)
        )
    }

    static func applyDockIconPreference(showDockIcon: Bool) {
        if !showDockIcon,
           !UserDefaults.standard.bool(forKey: AppPreferences.showMenuBarExtraKey) {
            UserDefaults.standard.set(true, forKey: AppPreferences.showMenuBarExtraKey)
        }
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let identifier = response.notification.request.identifier
        let noteIDString = Self.notificationNoteIDString(userInfo: userInfo, identifier: identifier)

        await MainActor.run {
            Self.openNoteViewerFromNotification(noteIDString: noteIDString)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: NSUserNotificationCenter,
        shouldPresent notification: NSUserNotification
    ) -> Bool {
        true
    }

    nonisolated func userNotificationCenter(
        _ center: NSUserNotificationCenter,
        didActivate notification: NSUserNotification
    ) {
        let noteIDString = Self.notificationNoteIDString(userInfo: notification.userInfo ?? [:], identifier: nil)
        Task { @MainActor in
            Self.openNoteViewerFromNotification(noteIDString: noteIDString)
        }
    }

    private static func openNoteViewerFromNotification(noteIDString: String?) {
        guard let noteIDString,
              let noteID = Note.ID(uuidString: noteIDString) else { return }
        NotificationCenter.default.post(name: .vellemOpenNoteViewer, object: noteID)
        NSApp.activate(ignoringOtherApps: true)
    }

    nonisolated private static func notificationNoteIDString(userInfo: [AnyHashable: Any], identifier: String?) -> String? {
        if let idString = userInfo[ExternalNoteEvent.noteIDKey] as? String {
            return idString
        }

        guard let identifier,
              identifier.hasPrefix("vellem-note-") else {
            return nil
        }

        return String(identifier.dropFirst("vellem-note-".count))
    }
}

extension Notification.Name {
    static let vellemOpenNoteViewer = Notification.Name("vellemOpenNoteViewer")
    static let vellemFocusSearch = Notification.Name("vellemFocusSearch")
}

struct ExternalNoteEventBridge: NSViewRepresentable {
    @ObservedObject var store: NotesStore

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.start()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.store = store
        // start() is guarded by observer == nil — no need to call it again here;
        // it already ran in makeNSView and re-calling it on every re-render is wasteful.
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator {
        var store: NotesStore
        private var observer: NSObjectProtocol?

        init(store: NotesStore) {
            self.store = store
        }

        func start() {
            guard observer == nil else { return }
            observer = DistributedNotificationCenter.default().addObserver(
                forName: ExternalNoteEvent.createdName,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self,
                      let idString = notification.userInfo?[ExternalNoteEvent.noteIDKey] as? String,
                      let noteID = UUID(uuidString: idString) else {
                    return
                }
                let source = notification.userInfo?[ExternalNoteEvent.sourceKey] as? String
                Task { @MainActor in
                    self.store.handleExternalNoteCreated(noteID: noteID, source: source)
                }
            }
        }

        func stop() {
            if let observer {
                DistributedNotificationCenter.default().removeObserver(observer)
            }
            observer = nil
        }
    }
}
