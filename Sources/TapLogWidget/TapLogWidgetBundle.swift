import WidgetKit
import SwiftUI

@main
struct TapLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        SpendWidget()
        if #available(iOS 18.0, *) {
            TapLogControlWidget()
        }
    }
}
