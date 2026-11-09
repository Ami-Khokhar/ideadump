import Foundation
import WidgetKit

struct QuickButton: Identifiable, Equatable {
    let amount: Double
    let categoryKey: String
    let emoji: String
    let label: String

    var id: String { "\(categoryKey)-\(amount)" }
}

struct SpendSnapshot: TimelineEntry {
    var date: Date
    var total: Decimal
    var count: Int
    let quickButtons: [QuickButton]
    /// False when the widget could not read the shared store, so it can say so
    /// instead of showing a plausible empty day.
    var isAvailable: Bool = true
}

/// The pure part of the spend widget's timeline: today's entry, the entry that
/// rolls the day over, and when to ask for another timeline.
///
/// Lives in `Shared` so the app target — and therefore the unit tests — can pin
/// the boundary arithmetic without running WidgetKit. `SpendProvider` supplies
/// `now` and the calendar; everything here is a function of those two.
enum SpendTimeline {
    /// Requests are a budget, not a schedule. 30 minutes is 48 a day, well under
    /// what WidgetKit is willing to grant a frequently seen widget, and the
    /// explicit reloads on log, undo, edit and foreground carry the rest.
    static let rollingInterval: TimeInterval = 30 * 60

    /// Returns the entry to show now, the zeroed entry at the next local
    /// midnight, and when to ask WidgetKit for another timeline — whichever of
    /// the rolling interval and midnight comes first.
    ///
    /// `calendar` decides where midnight is, so a 23- or 25-hour day lands on
    /// the real first instant of the next day rather than 24 hours later.
    static func entries(
        now: Date,
        snapshot: SpendSnapshot,
        calendar: Calendar
    ) -> (entries: [SpendSnapshot], refreshAfter: Date) {
        let startOfTomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        ) ?? now.addingTimeInterval(86_400)

        // Preserve the snapshot's other state when advancing its totals: the
        // learned quick buttons are the same on both sides of midnight.
        var midnightReset = snapshot
        midnightReset.date = startOfTomorrow
        midnightReset.total = 0
        midnightReset.count = 0

        let rollingRefresh = calendar.date(
            byAdding: .minute,
            value: 30,
            to: now
        ) ?? now.addingTimeInterval(rollingInterval)

        return ([snapshot, midnightReset], min(rollingRefresh, startOfTomorrow))
    }
}
