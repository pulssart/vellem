import Foundation
import WidgetKit

enum WidgetReloader {
    private static let widgetKind = "VellemWidget"

    static func reload() {
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        WidgetCenter.shared.reloadAllTimelines()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        }
    }
}
