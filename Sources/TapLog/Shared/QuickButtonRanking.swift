import Foundation

/// Picks which (category, amount) pairs become the widget's quick-log buttons.
///
/// This lives apart from the widget view for one reason: these buttons log money
/// on a single tap, with no confirmation dialog and no undo on the screen the
/// user is looking at. A button that moves between refreshes turns a tap aimed at
/// ₹45 of chai into ₹120 of rent. Ordering that matters that much should be
/// testable, and the widget target is not.
enum QuickButtonRanking {
    /// A purchase shape the user repeats: a category plus a rounded amount.
    struct Pattern: Hashable {
        let categoryKey: String
        let amount: Decimal

        init(categoryKey: String, amount: Decimal) {
            self.categoryKey = categoryKey
            self.amount = amount
        }
    }

    /// The most repeated patterns first, capped at `limit`.
    ///
    /// `Dictionary` iteration order varies per process and `sorted(by:)` is not
    /// stable, so frequency alone is not an order — it is an order for the
    /// patterns that differ in count and a coin toss for the rest. Category key
    /// then amount breaks every remaining tie, which makes the result the same
    /// on every widget process for the same history. A brand-new user is the
    /// worst case: every count is 1, so without this the whole row is arbitrary.
    static func top(_ counts: [Pattern: Int], limit: Int = 3) -> [Pattern] {
        counts
            .sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                if $0.key.categoryKey != $1.key.categoryKey {
                    return $0.key.categoryKey < $1.key.categoryKey
                }
                return $0.key.amount < $1.key.amount
            }
            .prefix(limit)
            .map(\.key)
    }
}
