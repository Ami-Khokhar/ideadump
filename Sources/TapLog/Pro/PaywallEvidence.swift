import Foundation

/// What the user has already done, said back to them at the moment they are asked
/// to pay.
///
/// The paywall used to open on four invented trees. Invented trees argue that the
/// app is nice; the user's own 143 entries across 24 days argue that they already
/// kept the habit — which is the only argument that has ever sold a tracker. The
/// numbers are read from the local store and never leave it.
///
/// A pure value type with an injectable calendar, like the rest of the app's
/// math, so the counting rules are tested without a UI.
struct PaywallEvidence: Equatable {
    /// Confirmed, unarchived entries. The same set every screen in the app counts.
    let entryCount: Int
    /// Distinct calendar days that hold at least one entry.
    let dayCount: Int
    /// Everything those entries add up to.
    let tracked: Decimal

    /// Below this there is no record worth showing, and a thin number argues
    /// against paying rather than for it. Someone who has logged twice does not
    /// need to be told they have logged twice — they need the app to stay out of
    /// the way, so the paywall falls back to saying what Pro is.
    static let minimumEntries = 8
    static let minimumDays = 3

    var isWorthShowing: Bool {
        entryCount >= Self.minimumEntries && dayCount >= Self.minimumDays
    }

    static func make(
        entries: [Entry],
        calendar: Calendar = .current
    ) -> PaywallEvidence {
        let counted = entries.filter { !$0.isArchived && !$0.isPending }
        let days = Set(counted.map { calendar.startOfDay(for: $0.date) })
        return PaywallEvidence(
            entryCount: counted.count,
            dayCount: days.count,
            tracked: counted.reduce(Decimal(0)) { $0 + $1.amount }
        )
    }

    /// "143 expenses · 24 days · ₹18,400 tracked".
    ///
    /// Deliberately three plain facts in the user's own currency, with no adjective
    /// anywhere near them. The sentence that sells is the one the reader writes in
    /// their own head while reading it.
    var summaryLine: String {
        "\(entryCount) \(entryCount == 1 ? "expense" : "expenses") · \(dayCount) \(dayCount == 1 ? "day" : "days") · \(Money.format(tracked)) tracked"
    }
}
