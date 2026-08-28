import Foundation

/// Pure math behind the weekly recap, extracted from `WeeklyRecapView` so it can be
/// unit-tested deterministically. All functions take an explicit calendar and
/// reference date; production callers use the defaults.
enum RecapMath {
    /// Entries from the current calendar week (per the locale's first weekday) and
    /// the previous one.
    static func splitWeeks(
        _ entries: [Entry],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> (thisWeek: [Entry], lastWeek: [Entry]) {
        let thisInterval = calendar.dateInterval(of: .weekOfYear, for: now)!
        let thisStart = thisInterval.start
        let lastStart = calendar.date(byAdding: .day, value: -7, to: thisStart)!
        // Future-dated entries sit inside the current week interval but haven't
        // happened yet, so they must not inflate this week's total.
        let thisWeek = entries.filter { $0.date >= thisStart && $0.date < thisInterval.end && $0.date <= now }
        let lastWeek = entries.filter { $0.date >= lastStart && $0.date < thisStart }
        return (thisWeek, lastWeek)
    }

    /// Totals per day of week for the given (current) week. Index 0 is the
    /// calendar's first weekday (locale-driven: Sunday for en_US/en_IN, Monday
    /// for much of Europe); entries outside that week are ignored.
    static func dailyTotals(
        _ week: [Entry],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> [Decimal] {
        let start = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        var result = Array(repeating: Decimal(0), count: 7)
        for entry in week {
            // Same future cut-off `splitWeeks` applies. Without it a
            // future-dated entry was left out of the week's total yet still
            // drew a bar in the chart above it — the two halves of one recap
            // disagreeing about whether the money had been spent.
            guard entry.date <= now else { continue }
            // Compare day boundaries: raw dateComponents truncate toward zero,
            // so an entry hours before the week start would round up to 0 and
            // leak into the first bar.
            let day = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: start),
                to: calendar.startOfDay(for: entry.date)
            ).day ?? 0
            guard day >= 0 && day < 7 else { continue }
            result[day] += entry.amount
        }
        return result
    }

    /// Spend grouped by category key.
    static func totals(byCategory entries: [Entry]) -> [String: Decimal] {
        var result: [String: Decimal] = [:]
        for entry in entries {
            result[entry.category, default: 0] += entry.amount
        }
        return result
    }

    /// Today's index into the week arrays. Derived from the same week interval
    /// as `dailyTotals`, so the highlighted bar and the buckets can never
    /// disagree about where the week starts (the old `(weekday + 5) % 7` math
    /// hardcoded Monday-first and shifted every bar in Sunday-first locales).
    static func todayIndex(calendar: Calendar = .current, now: Date = .now) -> Int {
        let start = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let day = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        return min(6, max(0, day))
    }

    // MARK: - Impulse vs. planned

    /// A period's impulse-versus-planned read.
    ///
    /// The three buckets are kept apart on purpose. Every ratio this exposes is
    /// taken over *marked* spend only, because an unmarked entry carries no claim
    /// either way — folding it into either side would manufacture an opinion the
    /// user never expressed. `unmarked` is retained solely so callers can state
    /// how complete the read is.
    struct IntentBreakdown: Equatable, Sendable {
        var impulse: Decimal = 0
        var planned: Decimal = 0
        var unmarked: Decimal = 0
        /// Entry counts, so a caller can say "8 of 14 entries" without re-walking.
        var markedCount: Int = 0
        var entryCount: Int = 0

        /// Spend the user actually took a position on.
        var marked: Decimal { impulse + planned }
        /// Everything in the period, marked or not.
        var total: Decimal { marked + unmarked }

        /// Impulse as a share of marked spend, or nil when there is nothing to
        /// take a share of. Nil rather than zero: "0% impulse" and "you haven't
        /// told me yet" are different statements, and only one of them is true.
        var impulseShare: Decimal? {
            guard markedCount > 0, marked > 0 else { return nil }
            return impulse / marked
        }

        /// How much of the period's spend carries a mark — the honesty figure.
        /// Nil for an empty period, where coverage is meaningless rather than 0%.
        var coverage: Decimal? {
            guard total > 0 else { return nil }
            return marked / total
        }
    }

    /// Splits a period's spend into impulse, planned, and unmarked.
    static func intentBreakdown(_ entries: [Entry]) -> IntentBreakdown {
        var result = IntentBreakdown()
        for entry in entries {
            result.entryCount += 1
            switch entry.intent {
            case .impulse:
                result.impulse += entry.amount
                result.markedCount += 1
            case .planned:
                result.planned += entry.amount
                result.markedCount += 1
            case nil:
                result.unmarked += entry.amount
            }
        }
        return result
    }

    /// The same split, per category key — so "which categories are impulse-heavy"
    /// is answerable without a second pass over the entries.
    static func intentBreakdown(byCategory entries: [Entry]) -> [String: IntentBreakdown] {
        var result: [String: IntentBreakdown] = [:]
        for entry in entries {
            var bucket = result[entry.category] ?? IntentBreakdown()
            bucket.entryCount += 1
            switch entry.intent {
            case .impulse:
                bucket.impulse += entry.amount
                bucket.markedCount += 1
            case .planned:
                bucket.planned += entry.amount
                bucket.markedCount += 1
            case nil:
                bucket.unmarked += entry.amount
            }
            result[entry.category] = bucket
        }
        return result
    }

    /// Change in impulse share between two periods, in percentage *points*.
    ///
    /// Points, not a percentage of a percentage: 40% → 50% is "10 points", and
    /// calling that "25% more impulsive" would be a different — and much
    /// louder — claim than the data supports. Nil unless both periods have marked
    /// spend, since a share can only be compared with another share.
    static func impulseShareDelta(
        current: IntentBreakdown,
        previous: IntentBreakdown
    ) -> Decimal? {
        guard let now = current.impulseShare, let before = previous.impulseShare else {
            return nil
        }
        return now - before
    }

    /// Weekday labels aligned with `dailyTotals`/`todayIndex`: element 0 is the
    /// calendar's first weekday, produced by rotating the locale's
    /// `veryShortWeekdaySymbols` — localisation comes for free.
    static func weekdayLabels(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let offset = max(0, calendar.firstWeekday - 1)
        return (0..<7).map { index in symbols[(index + offset) % symbols.count].uppercased() }
    }
}
