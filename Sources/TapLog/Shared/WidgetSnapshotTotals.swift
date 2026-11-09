import Foundation

/// Maps one widget store read into the figures the widget renders.
///
/// This lives here rather than in the widget target because `TapLogTests` links
/// the app, not the extension. A failure that turns into a valid-looking zero is
/// exactly the bug this mapping exists to prevent, so the mapping has to be
/// testable.
enum WidgetSnapshotTotals {
    struct Totals: Equatable {
        let total: Decimal
        let count: Int
        let isAvailable: Bool
    }

    /// A throwing reader — a store that would not open, a fetch that failed — is
    /// the unavailable state, never a plausible empty day.
    static func map(read: () throws -> [Entry]) -> Totals {
        do {
            let entries = try read()
            return Totals(
                total: entries.reduce(Decimal(0)) { $0 + $1.amount },
                count: entries.count,
                isAvailable: true
            )
        } catch {
            Log.store.error("widget snapshot unavailable: shared store read failed (\(Log.describe(error), privacy: .public))")
            return Totals(total: 0, count: 0, isAvailable: false)
        }
    }
}
