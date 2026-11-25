import SwiftUI

struct MailboxUnreadDot: View {
    var body: some View {
        Circle()
            .fill(.orange)
            .frame(width: 7, height: 7)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}
