import BackgroundTasks
import SwiftUI
import UIKit
import UserNotifications

@main
struct VellemMobileApp: App {
    @UIApplicationDelegateAdaptor(MobileAppDelegate.self) private var appDelegate
    @StateObject private var store = MobileNotesStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MobileRootView(store: store)
                .onAppear {
                    store.start()
                }
                .onDisappear {
                    store.stop()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task {
                            await store.refresh()
                        }
                    } else if phase == .background {
                        MobileAppDelegate.scheduleRefresh()
                    }
                }
        }
    }
}

final class MobileAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private static let refreshTaskIdentifier = "com.adriendonot.Vellem.refresh"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        registerRefreshTask()
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    private func registerRefreshTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshTaskIdentifier,
            using: nil
        ) { task in
            self.handleRefresh(task: task as? BGAppRefreshTask)
        }
    }

    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleRefresh(task: BGAppRefreshTask?) {
        Self.scheduleRefresh()

        let refreshTask = Task {
            await MobileFolderNotificationScanner.refreshAndNotify()
            task?.setTaskCompleted(success: true)
        }

        task?.expirationHandler = {
            refreshTask.cancel()
            task?.setTaskCompleted(success: false)
        }
    }
}
