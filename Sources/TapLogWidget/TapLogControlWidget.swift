import AppIntents
import SwiftUI
import WidgetKit

/// iOS 18 Control Center control. OpenURLIntent is extension-safe and routes
/// through the same deep-link capture path as the widget and lock screen.
@available(iOS 18.0, *)
struct TapLogControlWidget: ControlWidget {
    static let kind = "dev.amteshwar.taplog.control"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenURLIntent(URL(string: "taplog://log")!)) {
                Label("Log expense", systemImage: "plus.circle.fill")
            }
        }
    }
}
