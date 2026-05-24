import Foundation
import WidgetKit

enum WidgetReloader {
    static func reload() {
        WidgetCenter.shared.reloadTimelines(ofKind: "VellemWidget")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
