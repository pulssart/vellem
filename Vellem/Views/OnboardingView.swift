import SwiftUI

struct FirstReceptionView: View {
    let connect: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image(decorative: "FoldPaper")
                .resizable()
                .scaledToFit()
                .frame(width: 156)
                .padding(.bottom, 25)
            Text("Receive your first message")
                .font(.system(size: 25, weight: .semibold))
                .tracking(-0.6)
                .accessibilityAddTraits(.isHeader)
            Text("Ask an agent to send a report, a note or a code snippet to Vellem.")
                .font(.system(size: 14))
                .foregroundStyle(InboxPalette.muted)
                .frame(maxWidth: 315)
                .padding(.top, 9)
            Button("Connect an agent…", action: connect)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .padding(.top, 18)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyAgentMailbox: View {
    let agent: InboxAgent
    @State private var copied = false
    @Environment(\.locale) private var locale
    private var request: String { VellemLanguage.text("Send this to Vellem.", locale: locale) }

    var body: some View {
        VStack(spacing: 9) {
            AgentMark(agent: agent, size: 28)
            Text("No messages from \(agent.rawValue) yet").font(.headline)
            Text("Ask \(agent.rawValue): “\(request)”")
                .font(.callout).foregroundStyle(.secondary)
            Button(copied ? "Copied" : "Copy request") {
                NSPasteboard.general.clearContents()
                copied = NSPasteboard.general.setString(request, forType: .string)
            }
        }
    }
}

struct MessageSelectionPlaceholder: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(decorative: "FoldPaper")
                .resizable().scaledToFit().frame(width: 24)
            Text("Select a message to read").font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct OnboardingView: View {
    @Binding var isPresented: Bool
    let connect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(decorative: "FoldMark").resizable().scaledToFit().frame(width: 29)
                Text("Vellem").font(.system(size: 26, weight: .semibold)).tracking(-0.8)
            }
            Text("Connect an agent, then ask it to send a report, a note or a code snippet to Vellem.")
                .font(.body)
            Text("Select an agent in the sidebar to read its messages. Select it again to open its folders.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Button("Done") { isPresented = false }
                Spacer()
                Button("Connect an agent…") {
                    isPresented = false
                    connect()
                }
                .keyboardShortcut(.defaultAction)
            }.padding(.top, 8)
        }
        .padding(28).frame(width: 430)
    }
}
