import SwiftUI
import UserNotifications

@main
struct VellemApp: App {
    @Environment(\.openWindow) private var openWindow

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = NotesStore()
    @State private var quickText = ""
    @AppStorage(AppPreferences.showMenuBarExtraKey) private var showMenuBarExtra = true
    @AppStorage(AppPreferences.showDockIconKey) private var showDockIcon = true
    @AppAccent private var accent
    @StateObject private var updateController = UpdateController.shared

    init() {
        AppPreferences.registerDefaults()
    }

    var body: some Scene {
        WindowGroup("Vellem", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 1080, minHeight: 620)
                .tint(accent.color)
                .background(ExternalNoteEventBridge(store: store))
                .onOpenURL { url in
                    handle(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .vellemSaveSelection)) { notification in
                    if let capture = notification.object as? SelectionCapture {
                        store.captureFromServices(text: capture.text, source: capture.source)
                    } else if let text = notification.object as? String {
                        store.captureFromServices(text: text)
                    }
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                }
                .onReceive(NotificationCenter.default.publisher(for: .vellemOpenQuickCapture)) { _ in
                    openQuickCapture()
                }
                .onReceive(NotificationCenter.default.publisher(for: .vellemOpenNoteViewer)) { notification in
                    guard let noteID = notification.object as? Note.ID else { return }
                    store.viewerNoteID = noteID
                    openWindow(id: "note-viewer")
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updateController.checkForUpdates()
                }
                .disabled(!updateController.canCheckForUpdates)
            }

            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    store.createDraft()
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Quick Capture") {
                    openQuickCapture()
                }

                Button("Open Today") {
                    store.upsertDailyNote()
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .option])

                Button("Show Vellem") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra("Vellem", systemImage: "note.text.badge.plus", isInserted: menuBarExtraBinding) {
            MenuBarComposerView(store: store, text: $quickText)
                .frame(width: 360)
                .tint(accent.color)
        }
        .menuBarExtraStyle(.window)

        Window("Quick Capture", id: "quick-capture") {
            QuickCaptureView(store: store)
                .tint(accent.color)
        }
        .defaultSize(width: 420, height: 300)
        .windowResizability(.automatic)
        .windowStyle(.hiddenTitleBar)

        Window("View Note", id: "note-viewer") {
            NoteViewerView(store: store)
                .tint(accent.color)
        }
        .defaultSize(width: 560, height: 600)
        .windowResizability(.automatic)
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView()
        }
    }

    private func handle(_ url: URL) {
        guard url.scheme == "vellem" else { return }
        if url.host == "new" {
            openQuickCapture()
            hideMainWindowAfterOpeningQuickCapture()
        } else if url.host == "note",
                  let idString = url.pathComponents.dropFirst().first,
                  let uuid = UUID(uuidString: idString) {
            store.viewerNoteID = uuid
            openWindow(id: "note-viewer")
            NSApp.activate(ignoringOtherApps: true)
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func openQuickCapture() {
        openWindow(id: "quick-capture")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hideMainWindowAfterOpeningQuickCapture() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            for window in NSApp.windows where window.title != "Quick Capture" {
                window.orderOut(nil)
            }
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
    private let servicesProvider = SelectionServicesProvider()
    private let hotKeyService = GlobalHotKeyService()
    private var activationObserver: NSObjectProtocol?
    private var observesPreferences = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppPreferences.registerDefaults()
        Self.applyDockIconPreference(
            showDockIcon: UserDefaults.standard.bool(forKey: AppPreferences.showDockIconKey)
        )
        NSApp.servicesProvider = servicesProvider
        NSUserNotificationCenter.default.delegate = self
        NoteNotifications.requestAuthorization(delegate: self)
        hotKeyService.register()
        observeActiveApplications()
        observePreferenceChanges()

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    private func observeActiveApplications() {
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }

            Task { @MainActor in
                CaptureContextProvider.rememberActiveApplication(application)
            }
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
    static let vellemSaveSelection = Notification.Name("vellemSaveSelection")
    static let vellemOpenQuickCapture = Notification.Name("vellemOpenQuickCapture")
    static let vellemOpenNoteViewer = Notification.Name("vellemOpenNoteViewer")
    static let vellemShowOnboarding = Notification.Name("vellemShowOnboarding")
}

struct SelectionCapture {
    var text: String
    var source: CaptureSource
}

@MainActor
final class SelectionServicesProvider: NSObject {
    @objc func addSelectionToVellem(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let text = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            error.pointee = "No selected text found."
            return
        }

        let capture = SelectionCapture(text: text, source: CaptureContextProvider.currentSource())
        NotificationCenter.default.post(name: .vellemSaveSelection, object: capture)
    }
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
        context.coordinator.start()
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
