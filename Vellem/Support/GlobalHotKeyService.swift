import Carbon
import Foundation

final class GlobalHotKeyService: NSObject {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var observesDefaults = false

    func register() {
        AppPreferences.registerDefaults()
        installEventHandlerIfNeeded()
        registerCurrentShortcut()
        guard !observesDefaults else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(defaultsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        observesDefaults = true
    }

    private func registerCurrentShortcut() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        let shortcut = AppPreferences.quickCaptureShortcut
        let hotKeyID = EventHotKeyID(signature: OSType("SPNT".fourCharCode), id: 1)
        RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ in
                NotificationCenter.default.post(name: .vellemOpenQuickCapture, object: nil)
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )
    }

    @objc private func defaultsChanged(_ notification: Notification) {
        registerCurrentShortcut()
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }

        if observesDefaults {
            NotificationCenter.default.removeObserver(
                self,
                name: UserDefaults.didChangeNotification,
                object: nil
            )
        }
    }
}

private extension String {
    var fourCharCode: FourCharCode {
        utf8.reduce(0) { result, character in
            (result << 8) + FourCharCode(character)
        }
    }
}
