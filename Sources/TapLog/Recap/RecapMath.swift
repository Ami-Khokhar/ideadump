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
        let thisWeek = entries.filter { $0.date >= thisStart && $0.date < thisInterval.end }
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

    /// Weekday labels aligned with `dailyTotals`/`todayIndex`: element 0 is the
    /// calendar's first weekday, produced by rotating the locale's
    /// `veryShortWeekdaySymbols` — localisation comes for free.
    static func weekdayLabels(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let offset = max(0, calendar.firstWeekday - 1)
        return (0..<7).map { index in symbols[(index + offset) % symbols.count].uppercased() }
    }
}
