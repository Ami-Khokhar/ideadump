import Foundation

/// Decides whether the app should spend widget-refresh budget asking WidgetKit to
/// rebuild the spend widget.
///
/// Every capture path already asks for a reload where it writes: log and undo
/// (`CaptureBookkeeping`), edit (`CaptureForm`), delete-all (`SettingsView`,
/// `EntryListView`), and a widget quick-log (through `CaptureBookkeeping`) all
/// call `reloadTimelines` themselves. The two requests added for issue #62 — a
/// currency change and a foregrounding — are the app's chance to repair a reload
/// WidgetKit deferred while it was not watching. So they ask only when the state
/// the widget renders has moved since the last request, and a plain foregrounding
/// spends nothing.
enum WidgetReload {
    /// The app's only widget, named once so every request agrees.
    static let kind = "SpendWidget"

    /// What a rebuild would render, as cheaply as the app can read it.
    ///
    /// The log counter is `CaptureBookkeeping`'s, which every capture front door
    /// shares — a log, an undo, or a widget quick-log moves it. An amount edit
    /// does not, and reaches the widget through its own reload instead.
    struct Inputs: Equatable {
        var logCount: Int
        var currencyCode: String
    }

    private enum Keys {
        static let logCount = "widgetReload.logCount"
        static let currencyCode = "widgetReload.currencyCode"
    }

    /// Reads the values a rebuild would render from the defaults the widget and
    /// the app share.
    static func currentInputs(
        defaults: UserDefaults = StoreLocator.sharedDefaults
    ) -> Inputs {
        Inputs(
            logCount: defaults.integer(forKey: "logsLogged"),
            currencyCode: defaults.string(forKey: "currencyCode") ?? Money.currencyCode
        )
    }

    /// True when `inputs` differ from the state the last request described — that
    /// is, when the widget could be showing something stale. A true answer records
    /// the new state, so the same stale content cannot cost two requests.
    @discardableResult
    static func shouldRequest(
        _ inputs: Inputs,
        defaults: UserDefaults = StoreLocator.sharedDefaults
    ) -> Bool {
        let previousCount = defaults.object(forKey: Keys.logCount) as? Int
        let previousCurrency = defaults.string(forKey: Keys.currencyCode)
        guard previousCount != inputs.logCount || previousCurrency != inputs.currencyCode else {
            return false
        }
        defaults.set(inputs.logCount, forKey: Keys.logCount)
        defaults.set(inputs.currencyCode, forKey: Keys.currencyCode)
        return true
    }
}
