import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage(AppPreferences.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false
    @State private var selectedStep = 0

    private let steps = OnboardingStep.all

    var body: some View {
        VStack(spacing: 0) {
            header

            OnboardingStepView(step: steps[selectedStep])
                .id(steps[selectedStep].id)
                .transition(.opacity)
            .frame(width: 540, height: 320)

            footer
        }
        .frame(width: 540)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome to Vellem")
                    .font(.title3.weight(.semibold))
                Text("Four things worth knowing.")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 26)
        .padding(.bottom, 10)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { index in
                    Circle()
                        .fill(index == selectedStep ? Color.accentColor : Color.secondary.opacity(0.28))
                        .frame(width: 7, height: 7)
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
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }
}

private struct OnboardingStepView: View {
    let step: OnboardingStep

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: step.symbol)
                .font(.system(size: 36, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 8) {
                Text(step.title)
                    .font(.title2.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(step.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let callout = step.callout {
                Text(callout)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
    }
}

private struct OnboardingStep: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let body: String
    let callout: String?

    static var all: [OnboardingStep] {
        [
            OnboardingStep(
                symbol: "keyboard",
                title: "Open Quick Note from anywhere",
                body: "Use the keyboard shortcut to bring up the small Quick Note window. Write the thought, save it, and Vellem gets out of your way.",
                callout: "Default shortcut: \(ShortcutFormatter.string(for: AppPreferences.quickCaptureShortcut))"
            ),
            OnboardingStep(
                symbol: "point.3.connected.trianglepath.dotted",
                title: "Connect Claude or Codex",
                body: "Open the Claude or Codex folder in the sidebar, copy the MCP config, then add it to your client. After that, agents can write notes directly into Vellem.",
                callout: nil
            ),
            OnboardingStep(
                symbol: "text.cursor",
                title: "Save text from your browser",
                body: "Select text in any browser, right click, open Services, then choose Add to Vellem. The selection is saved as a note.",
                callout: "Works with any app that exposes selected text to macOS Services."
            ),
            OnboardingStep(
                symbol: "sparkles",
                title: "Improve notes with Apple Foundation Models",
                body: "Vellem includes tools that can clean up, format, rewrite, translate, and adjust the style of your notes with Apple Foundation Models.",
                callout: "If the model is not available on this Mac, Vellem will say so."
            )
        ]
    }
}
