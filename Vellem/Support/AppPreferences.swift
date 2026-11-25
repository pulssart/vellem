import Foundation

enum AppPreferences {
    static let settingsTabKey = "VellemSettingsTab"
    static let showMenuBarExtraKey = "showMenuBarExtra"
    static let showDockIconKey = "showDockIcon"
    static let hasReceivedMessagesKey = "hasReceivedMessages"
    static let hiddenInboxAgentsKey = "hiddenInboxAgents"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            showMenuBarExtraKey: true,
            showDockIconKey: true,
            hasReceivedMessagesKey: false,
            hiddenInboxAgentsKey: HiddenInboxAgents().rawValue
        ])
    }
}

struct HiddenInboxAgents: RawRepresentable, Equatable {
    private var names: Set<String>

    init(rawValue: String = "") {
        names = Set(rawValue.split(separator: ",").map(String.init))
    }

    var rawValue: String { names.sorted().joined(separator: ",") }

    func isVisible(_ agent: InboxAgent) -> Bool {
        !names.contains(agent.rawValue)
    }

    mutating func setVisible(_ visible: Bool, for agent: InboxAgent) {
        if visible {
            names.remove(agent.rawValue)
        } else {
            names.insert(agent.rawValue)
        }
    }
}
