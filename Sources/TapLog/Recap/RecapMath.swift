import Foundation

/// Pure math behind the weekly recap, extracted from `WeeklyRecapView` so it can be
/// unit-tested deterministically. All functions take an explicit calendar and
/// reference date; production callers use the defaults.
enum RecapMath {
    /// Entries from the current week (from Monday 00:00) and the previous one.
    static func splitWeeks(
        _ entries: [Entry],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> (thisWeek: [Entry], lastWeek: [Entry]) {
        let thisStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let lastStart = calendar.date(byAdding: .day, value: -7, to: thisStart)!
        let thisWeek = entries.filter { $0.date >= thisStart }
        let lastWeek = entries.filter { $0.date >= lastStart && $0.date < thisStart }
        return (thisWeek, lastWeek)
    }

    /// Totals per day of week for the given (current) week. Index 0 = Monday … 6 =
    /// Sunday; entries outside Mon–Sun of that week are ignored.
    static func dailyTotals(
        _ week: [Entry],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> [Decimal] {
        let start = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        var result = Array(repeating: Decimal(0), count: 7)
        for entry in week {
            let day = calendar.dateComponents([.day], from: start, to: entry.date).day ?? 0
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

    /// Today's index into the Monday-first arrays (Mon = 0 … Sun = 6).
    static func todayIndex(calendar: Calendar = .current, now: Date = .now) -> Int {
        (calendar.component(.weekday, from: now) + 5) % 7
    }
}
