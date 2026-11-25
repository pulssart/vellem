import SwiftUI

struct MessageCopyLabel: View {
    let token: UUID?
    var action: LocalizedStringKey = "Copy text"
    var confirmation: LocalizedStringKey = "Copied"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(macOS)
    @ScaledMetric private var iconSize: CGFloat = 16
    #else
    @ScaledMetric private var iconSize: CGFloat = 20
    #endif

    var body: some View {
        Label {
            ZStack(alignment: .leading) {
                Text(action).opacity(token == nil ? 1 : 0)
                Text(confirmation).opacity(token == nil ? 0 : 1)
            }
        } icon: {
            CopySheets(copied: token != nil, reduceMotion: reduceMotion)
                .id(token)
                .frame(width: iconSize, height: iconSize)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(token == nil ? action : confirmation))
    }
}

private struct CopySheets: View {
    let copied: Bool
    let reduceMotion: Bool
    @State private var unfolded = false

    var body: some View {
        let settled = copied && (unfolded || reduceMotion)
        GeometryReader { geometry in
            let unit = geometry.size.width / 22
            let pen = StrokeStyle(lineWidth: unit * 1.55, lineCap: .round, lineJoin: .round)

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 4 * unit, y: 6 * unit))
                    path.addQuadCurve(to: CGPoint(x: 2.5 * unit, y: 8 * unit),
                                      control: CGPoint(x: 2.5 * unit, y: 6 * unit))
                    path.addLine(to: CGPoint(x: 2.5 * unit, y: 18.5 * unit))
                    path.addQuadCurve(to: CGPoint(x: 4.5 * unit, y: 20.5 * unit),
                                      control: CGPoint(x: 2.5 * unit, y: 20.5 * unit))
                    path.addLine(to: CGPoint(x: 12 * unit, y: 20.5 * unit))
                }
                .stroke(style: pen)
                .opacity(settled ? 0.5 : 0.85)

                ZStack {
                    Image(systemName: "doc")
                        .resizable().scaledToFit()
                        .frame(width: 13 * unit, height: 16 * unit)
                        .position(x: 12.5 * unit, y: 10 * unit)
                    Path { path in
                        path.move(to: CGPoint(x: 9.5 * unit, y: 11 * unit))
                        path.addLine(to: CGPoint(x: 11.6 * unit, y: 13.2 * unit))
                        path.addLine(to: CGPoint(x: 15.6 * unit, y: 9 * unit))
                    }
                    .trim(from: 0, to: settled ? 1 : 0)
                    .stroke(style: pen)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2).delay(0.09), value: unfolded)
                }
                .offset(x: settled ? 1.4 * unit : 0, y: settled ? -1.3 * unit : 0)
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.32, bounce: 0.12), value: unfolded)
        }
        .onAppear { if copied && !reduceMotion { unfolded = true } }
    }
}
