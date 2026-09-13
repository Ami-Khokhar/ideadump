import Foundation

/// A note the widget leaves for the app: "I logged this on your behalf, while you
/// were somewhere else."
///
/// The widget is the only capture front door with no way back. Every other one
/// leaves a five-second undo toast on the screen the user is already looking at;
/// a widget tap writes an expense into a store nobody is watching and returns to
/// the Home Screen. A tap meant for the app icon becomes ₹120 of rent that only a
/// trip through History will remove — and the whole promise of the widget is that
/// you never have to make that trip.
///
/// So the widget records what it did, and the app offers the same undo it offers
/// everywhere else the next time it opens. The receipt names the entry by the
/// instant it was created, which is unique per insert, rather than by a new stored
/// identifier: the store's schema should not grow a field to serve a toast.
struct WidgetLogReceipt: Equatable {
    /// Matches `Entry.createdAt` exactly — that is how the app finds the row again.
    let createdAt: Date
    let amount: Decimal
    let categoryKey: String

    /// After this, the log is no longer news. Someone opening the app the next
    /// morning wants their keypad, not a toast about yesterday's chai.
    static let window: TimeInterval = 10 * 60

    private enum Keys {
        static let createdAt = "widgetLog.createdAt"
        static let amount = "widgetLog.amount"
        static let category = "widgetLog.category"
    }

    /// Called from the widget's process, which shares only `UserDefaults` and the
    /// store with the app. Only the newest tap is kept: three quick taps are one
    /// piece of news, and the toast can only show one of them anyway.
    static func write(
        _ receipt: WidgetLogReceipt,
        defaults: UserDefaults = StoreLocator.sharedDefaults
    ) {
        defaults.set(receipt.createdAt.timeIntervalSinceReferenceDate, forKey: Keys.createdAt)
        defaults.set(NSDecimalNumber(decimal: receipt.amount).stringValue, forKey: Keys.amount)
        defaults.set(receipt.categoryKey, forKey: Keys.category)
    }

    /// Reads and clears in one step. Returns nil when nothing is pending or the
    /// window has passed; either way the slot is empty afterwards, so one tap can
    /// never produce two toasts.
    static func consume(
        now: Date = .now,
        defaults: UserDefaults = StoreLocator.sharedDefaults
    ) -> WidgetLogReceipt? {
        guard defaults.object(forKey: Keys.createdAt) != nil else { return nil }

        let createdAt = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: Keys.createdAt))
        let amount = Decimal(string: defaults.string(forKey: Keys.amount) ?? "") ?? 0
        let categoryKey = defaults.string(forKey: Keys.category) ?? SpendCategory.fallbackKey
        clear(defaults: defaults)

        let age = now.timeIntervalSince(createdAt)
        // A negative age means the clock moved backwards between the write and the
        // read. That receipt describes a time that hasn't happened, so it is not
        // news either.
        guard age >= 0, age <= window else { return nil }
        return WidgetLogReceipt(createdAt: createdAt, amount: amount, categoryKey: categoryKey)
    }

    static func clear(defaults: UserDefaults = StoreLocator.sharedDefaults) {
        defaults.removeObject(forKey: Keys.createdAt)
        defaults.removeObject(forKey: Keys.amount)
        defaults.removeObject(forKey: Keys.category)
    }
}
