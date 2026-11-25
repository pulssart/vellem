import AppKit

@MainActor
final class MobileMailboxMonitor {
    private var timer: Timer?
    private var connection: NSXPCConnection?

    func start() {
        guard timer == nil, VellemStorageEnvironment.isolatedDirectory == nil else { return }
        poll()
        timer = .scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        timer?.tolerance = 3
    }

    private func poll() {
        guard connection == nil else { return }
        let link = NSXPCConnection(serviceName: ReplyServiceIdentity.name)
        link.remoteObjectInterface = NSXPCInterface(with: VellemReplyServiceProtocol.self)
        connection = link
        let token = ObjectIdentifier(link)
        let finish: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in
                guard let self, let active = self.connection, ObjectIdentifier(active) == token else { return }
                self.connection = nil
                active.invalidate()
            }
        }
        link.interruptionHandler = finish
        link.invalidationHandler = finish
        link.resume()
        let remote = link.remoteObjectProxyWithErrorHandler { _ in finish() } as? VellemReplyServiceProtocol
        remote?.refreshMobileMailbox(completion: finish)
    }
}
