import AppKit

extension NSApplication {
    @MainActor
    var vellemMainWindow: NSWindow? {
        windows.first { $0.title == "Vellem" }
    }

    @MainActor
    func showVellemMainWindow() {
        vellemMainWindow?.makeKeyAndOrderFront(nil)
    }

    @MainActor
    func hideVellemMainWindow() {
        vellemMainWindow?.orderOut(nil)
    }
}
