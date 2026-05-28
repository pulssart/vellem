import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage(AppPreferences.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false
    @AppAccent private var accent
    @State private var selectedStep = 0

    private let steps = OnboardingStep.all

    var body: some View {
        ZStack {
            onboardingBackground

            VStack(spacing: 15) {
                header

                OnboardingStepView(
                    step: steps[selectedStep],
                    foreground: foreground
                )
                .id(steps[selectedStep].id)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
                .frame(height: 194)

                footer
            }
            .padding(22)
        }
        .frame(width: 590, height: 340)
        .foregroundStyle(foreground)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: shadowColor.opacity(0.18), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome to Vellem.")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                Text("A notebook agents can actually use.")
                    .font(.callout)
                    .foregroundStyle(foreground.opacity(0.62))
            }

            Spacer()
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == selectedStep ? foreground : foreground.opacity(0.28))
                        .frame(width: index == selectedStep ? 22 : 7, height: 7)
                }
            }

            Spacer()

            if selectedStep > 0 {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedStep -= 1
                    }
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .buttonStyle(.plain)
                .foregroundStyle(foreground.opacity(0.78))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(foreground.opacity(0.10), in: Capsule())
            }

            Button(selectedStep == steps.count - 1 ? "Done" : "Next") {
                if selectedStep == steps.count - 1 {
                    hasCompletedOnboarding = true
                    isPresented = false
                } else {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedStep += 1
                    }
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.plain)
            .foregroundStyle(buttonForeground)
            .padding(.horizontal, 17)
            .padding(.vertical, 9)
            .background(buttonBackground, in: Capsule())
        }
    }

    private var onboardingBackground: some View {
        LinearGradient(
            colors: [
                Color(nsColor: accent.onboardingGradientTop),
                Color(nsColor: accent.onboardingGradientBottom)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var foreground: Color {
        .black
    }

    private var backgroundColor: Color {
        Color(nsColor: accent.onboardingGradientBottom)
    }

    private var buttonBackground: Color {
        foreground
    }

    private var buttonForeground: Color {
        backgroundColor
    }

    private var shadowColor: Color {
        .black
    }
}

private struct OnboardingStepView: View {
    let step: OnboardingStep
    let foreground: Color

    @State private var copiedClient: OnboardingMCPClient?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(step.title)
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)

                Text(step.body)
                    .font(.system(size: 14))
                    .foregroundStyle(foreground.opacity(0.66))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if step.showsConnectionSetup {
                connectionSetup
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var connectionSetup: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ForEach(OnboardingMCPClient.allCases) { client in
                    Button {
                        copy(client.config)
                        copiedClient = client
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(1.4))
                            if copiedClient == client { copiedClient = nil }
                        }
                    } label: {
                        Label(
                            copiedClient == client ? "Copied for \(client.title)" : "Copy for \(client.title)",
                            systemImage: copiedClient == client ? "checkmark" : "doc.on.doc"
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(foreground)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(foreground.opacity(0.10), in: Capsule())
                }

                Spacer()
            }

            Text("Paste it into your client config, restart the app, then ask the agent to save plans and notes to Vellem.")
                .font(.caption)
                .foregroundStyle(foreground.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

private struct OnboardingStep: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    var showsConnectionSetup = false

    static var all: [OnboardingStep] {
        [
            OnboardingStep(
                title: "Capture before you sort.",
                body: "Open Quick Capture from anywhere, save the thought, then get back to what you were doing. Vellem is built for messy inputs first, clean structure later. The default shortcut is \(ShortcutFormatter.string(for: AppPreferences.quickCaptureShortcut)), but the important part is the rhythm: write now, organize when it actually matters."
            ),
            OnboardingStep(
                title: "Let agents write their traces.",
                body: "Claude, Codex, and other MCP clients can create notes, append to today, update existing work, and keep their source visible. Vellem keeps those traces in plain notes instead of hiding them in chat history. The result is easier to scan, easier to quote, and easier to reuse later."
            ),
            OnboardingStep(
                title: "Find the thread again.",
                body: "Use search for exact text, semantic search for meaning, Today for the current flow, and related notes when one note should lead to the next. Semantic search runs locally with Apple's on-device embeddings, so it feels like memory without turning your notebook into a black box."
            ),
            OnboardingStep(
                title: "Turn rough notes into work.",
                body: "Markdown rendering, todos, widgets, and Apple Foundation Models help notes become usable without leaving the app. Clean up a rough capture, rewrite a paragraph, translate a note, or keep the original as it is. The point is to make small edits feel close to the note itself."
            ),
            OnboardingStep(
                title: "Connect your agent.",
                body: "Copy the setup for Claude or Codex, paste it into the client config, then restart the app. From there, the agent can save plans, reports, diagnostics, and running notes into Vellem with the right folder already attached.",
                showsConnectionSetup: true
            )
        ]
    }
}

private enum OnboardingMCPClient: String, CaseIterable, Identifiable {
    case claude
    case codex

    var id: String { rawValue }

    var title: String {
        switch self {
        case .claude:
            "Claude"
        case .codex:
            "Codex"
        }
    }

    var config: String {
        switch self {
        case .claude:
            """
            {
              "mcpServers": {
                "vellem": {
                  "command": "/Applications/Vellem.app/Contents/Resources/vellem-mcp"
                }
              }
            }
            """
        case .codex:
            """
            [mcp_servers.vellem]
            command = "/Applications/Vellem.app/Contents/Resources/vellem-mcp"
            """
        }
    }
}

private extension AppAccentColor {
    var onboardingGradientTop: NSColor {
        nsColor.blended(withFraction: 0.42, of: .windowBackgroundColor) ?? nsColor
    }

    var onboardingGradientBottom: NSColor {
        nsColor.blended(withFraction: 0.78, of: .white) ?? nsColor
    }
}
