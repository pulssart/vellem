import CoreHaptics
import UIKit

@MainActor
final class MobileHaptics {
    static let shared = MobileHaptics()
    static let preferenceKey = "mobileHapticsEnabled"

    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private let selection = UISelectionFeedbackGenerator()
    private let impact = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()
    private var enabled: Bool {
        supportsHaptics && UIApplication.shared.applicationState == .active &&
            (UserDefaults.standard.object(forKey: Self.preferenceKey) as? Bool ?? true)
    }

    func selectionChanged() {
        if enabled { selection.selectionChanged() }
    }

    func confirm() {
        if enabled { impact.impactOccurred(intensity: 0.65) }
    }

    func notify(_ result: UINotificationFeedbackGenerator.FeedbackType) {
        if enabled { notification.notificationOccurred(result) }
    }
}
