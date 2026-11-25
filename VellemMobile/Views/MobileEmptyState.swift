import SwiftUI

struct MobileEmptyState: View {
    enum Artwork: Equatable {
        case open(InboxAgent?), read, search, folder, document
    }

    let artwork: Artwork
    let title: String
    let detail: String
    var compact = false
    var actionTitle: String?
    var action: () -> Void = {}

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            PaperIllustration(artwork: artwork)
                .frame(width: compact ? 86 : typeSize.isAccessibilitySize ? 104 : 158,
                       height: compact ? 64 : typeSize.isAccessibilitySize ? 78 : 119)
                .accessibilityHidden(true)
                .padding(.bottom, compact ? 8 : 22)
            Text(LocalizedStringKey(title))
                .font(.system(compact ? .title2 : .title, weight: .semibold))
                .tracking(-0.8)
                .foregroundStyle(Color(white: 0.09))
                .accessibilityAddTraits(.isHeader)
            Text(LocalizedStringKey(detail))
                .font(.subheadline)
                .foregroundStyle(Color(white: 0.35))
                .padding(.top, 8)
            if let actionTitle {
                Button(action: action) {
                    Text(LocalizedStringKey(actionTitle))
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background(Color(white: 0.94), in: Capsule())
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, compact ? 8 : 16)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 330)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}

private struct PaperIllustration: View {
    let artwork: MobileEmptyState.Artwork

    var body: some View {
        if case .open(let agent) = artwork {
            Image(decorative: "FoldPaper")
                .resizable().scaledToFit()
                .shadow(color: .black.opacity(0.10), radius: 4, y: 5)
                .overlay(alignment: .bottomTrailing) {
                    if let agent { MobileAgentMark(agent: agent).padding(.trailing, 1) }
                }
        } else {
            Canvas { context, size in
                let scale = min(size.width / 160, size.height / 120)
                context.translateBy(x: (size.width - 160 * scale) / 2, y: (size.height - 120 * scale) / 2)
                context.scaleBy(x: scale, y: scale)
                // Draw the paper as one object so folds cast a single shadow.
                context.addFilter(.shadow(color: .black.opacity(0.13), radius: 3.5, y: 4))
                context.drawLayer { ink in
                    switch artwork {
                    case .read: envelope(in: ink)
                    case .search: document(in: ink, withLens: true)
                    case .document: document(in: ink, withLens: false)
                    case .folder: folder(in: ink)
                    case .open: break
                    }
                }
            }
        }
    }

    private func path(_ vertices: [CGPoint], closed: Bool = true) -> Path {
        Path { path in
            path.addLines(vertices)
            if closed { path.closeSubpath() }
        }
    }

    private func panel(_ ink: GraphicsContext, _ vertices: [CGPoint], light: Double, shade: Double) {
        let shape = path(vertices)
        let bounds = shape.boundingRect
        ink.fill(shape, with: .linearGradient(
            Gradient(colors: [Color(white: light), Color(white: shade)]),
            startPoint: CGPoint(x: bounds.minX, y: bounds.minY),
            endPoint: CGPoint(x: bounds.maxX, y: bounds.maxY)))
        ink.stroke(shape, with: .color(.black.opacity(0.30)), lineWidth: 0.75)
    }

    private func envelope(in ink: GraphicsContext) {
        // The slanted flap repeats the asymmetric V of the brand mark.
        let a = CGPoint(x: 15, y: 36), b = CGPoint(x: 133, y: 20)
        let c = CGPoint(x: 145, y: 91), d = CGPoint(x: 27, y: 106)
        let crease = CGPoint(x: 78, y: 73)
        panel(ink, [a, b, c, d], light: 0.87, shade: 0.70)
        panel(ink, [d, crease, c], light: 0.97, shade: 0.86)
        panel(ink, [a, b, .init(x: 80, y: 76)], light: 0.65, shade: 0.48)
        panel(ink, [a, b, crease], light: 1, shade: 0.92)
        var letterhead = ink
        letterhead.translateBy(x: 42, y: 38)
        letterhead.rotate(by: .degrees(-8))
        letterhead.opacity = 0.76
        var mark = letterhead.resolve(Image("FoldMark"))
        mark.shading = .color(MobileStyle.graphite)
        letterhead.draw(mark, in: CGRect(x: 0, y: 0, width: 13, height: 13))
        // A small ink seal marks a letter that has already been read.
        let seal = CGRect(x: 111, y: 70, width: 21, height: 21)
        ink.fill(Path(ellipseIn: seal), with: .color(MobileStyle.graphite))
        ink.stroke(path([.init(x: 116, y: 81), .init(x: 120, y: 84), .init(x: 127, y: 76)], closed: false),
                   with: .color(.white), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
    }

    private func document(in ink: GraphicsContext, withLens: Bool) {
        let corner = CGPoint(x: 97, y: 9), tip = CGPoint(x: 118, y: 27)
        panel(ink, [.init(x: 44, y: 15), corner, tip, .init(x: 126, y: 101), .init(x: 54, y: 110)],
              light: 1, shade: 0.92)
        panel(ink, [corner, tip, .init(x: 99, y: 30)], light: 0.84, shade: 0.67)
        for (y, width) in [(44, 44), (53, 37), (62, 47)] {
            let start = CGPoint(x: 59 + Double(y - 44) / 9, y: Double(y))
            ink.stroke(path([start, .init(x: start.x + CGFloat(width), y: start.y - 5)], closed: false),
                       with: .color(Color(white: 0.55)), lineWidth: 1.5)
        }
        if withLens {
            let lens = Path(ellipseIn: CGRect(x: 84, y: 50, width: 38, height: 38))
            ink.stroke(path([.init(x: 117, y: 82), .init(x: 135, y: 98)], closed: false),
                       with: .color(MobileStyle.graphite), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            ink.fill(lens, with: .color(.white.opacity(0.39)))
            ink.stroke(lens, with: .color(MobileStyle.graphite), lineWidth: 3.5)
        }
    }

    private func folder(in ink: GraphicsContext) {
        panel(ink, [.init(x: 21, y: 45), .init(x: 51, y: 40), .init(x: 61, y: 46),
                    .init(x: 125, y: 37), .init(x: 136, y: 91), .init(x: 31, y: 108)],
              light: 0.77, shade: 0.53)
        panel(ink, [.init(x: 40, y: 30), .init(x: 96, y: 14), .init(x: 111, y: 22),
                    .init(x: 126, y: 79), .init(x: 56, y: 97)], light: 1, shade: 0.94)
        panel(ink, [.init(x: 96, y: 14), .init(x: 111, y: 22), .init(x: 99, y: 26)],
              light: 0.90, shade: 0.74)
        panel(ink, [.init(x: 21, y: 58), .init(x: 142, y: 42), .init(x: 136, y: 91),
                    .init(x: 31, y: 108)], light: 0.97, shade: 0.80)
    }
}

struct MobileFirstMessage: View {
    @Environment(\.locale) private var locale
    let agent: InboxAgent?
    @State private var copied = false

    var body: some View {
        MobileEmptyState(artwork: .open(agent), title: agent.map { VellemLanguage.format("No messages from %@ yet", $0.rawValue, locale: locale) } ?? "Your inbox is empty",
                         detail: VellemLanguage.format("Ask %@ to send its next reply to Vellem.", agent?.rawValue ?? VellemLanguage.text("your agent", locale: locale), locale: locale),
                         actionTitle: copied ? "Request copied" : "Copy request") {
            UIPasteboard.general.string = VellemLanguage.text("Send your last reply to Vellem, preserving the text and formatting.", locale: locale)
            copied = true
            MobileHaptics.shared.confirm()
            UIAccessibility.post(notification: .announcement, argument: VellemLanguage.text("Request copied", locale: locale))
        }
        .task(id: copied) {
            guard copied else { return }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            copied = false
        }
    }
}
