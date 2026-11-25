#if os(macOS)
import Foundation

enum ReplyServiceIdentity {
    static let name = "com.adriendonot.Vellem.Replies"
}

@objc protocol VellemReplyServiceProtocol {
    func refreshMobileMailbox(completion: @escaping @Sendable () -> Void)
    func send(noteID: String, requestID: String, question: String, completion: @escaping @Sendable (String?) -> Void)
}
#endif
