import Foundation

/// Chooses which categories get tiles on the capture screen.
///
/// Two rules, in order: categories you have set a budget on come first, and
/// within each group the ones you log most come first. Ties fall back to display
/// order and then the key, so the row is fully determined by the data and never
/// reshuffles between redraws.
///
/// This replaced a time-of-day ranker that split the last 60 days into weekday
/// and weekend, bucketed both into eight three-hour windows, and blended bucket
/// evidence against a global prior with Bayesian pseudo-observations. It was a
/// lot of machinery for a row of four tiles, and its behaviour was impossible to
/// predict from the outside — the tiles could differ before and after lunch, on a
/// Saturday, or after a single log, with no way for anyone to tell why. A
/// suggestion nobody can predict is one nobody can trust, and the fix for a wrong
/// tile was always the same anyway: tap "More".
enum CategorySuggestions {

    /// The categories to offer, best first.
    ///
    /// Every category is a candidate, not only ones already logged. Ranking only
    /// what has been logged is self-fulfilling: a category you just set a budget
    /// on could never earn a tile, so you would have to dig through the picker to
    /// log the one thing you explicitly said you wanted to track.
    ///
    /// The fallback ("Other") is excluded — the capture row draws its own tile
    /// for it, and offering it here would show it twice.
    static func topCategories(
        entries: [Entry],
        categories: [SpendCategory],
        maxSlots: Int = 4
    ) -> [String] {
        var logCounts: [String: Int] = [:]
        for entry in entries {
            logCounts[entry.category, default: 0] += 1
        }

        let budgeted = budgetedKeys(in: categories)

        return categories
            .map(\.key)
            .filter { $0 != SpendCategory.fallbackKey }
            .enumerated()
            .sorted { lhs, rhs in
                let lhsBudgeted = budgeted.contains(lhs.element)
                let rhsBudgeted = budgeted.contains(rhs.element)
                if lhsBudgeted != rhsBudgeted { return lhsBudgeted }

                let lhsCount = logCounts[lhs.element] ?? 0
                let rhsCount = logCounts[rhs.element] ?? 0
                if lhsCount != rhsCount { return lhsCount > rhsCount }

                // Display order, then key: without a total order, equal counts
                // sort arbitrarily and the tiles move on their own.
                if lhs.offset != rhs.offset { return lhs.offset < rhs.offset }
                return lhs.element < rhs.element
            }
            .prefix(maxSlots)
            .map(\.element)
    }

    /// Keys of categories carrying a usable budget — both a positive target and a
    /// period. A target with no cadence is an unfinished budget, and the grove
    /// grows no tree for it either.
    private static func budgetedKeys(in categories: [SpendCategory]) -> Set<String> {
        Set(
            categories
                .filter { category in
                    guard let target = category.budgetTarget, target > 0 else { return false }
                    return category.budgetPeriod != nil
                }
                .map(\.key)
                .filter { $0 != SpendCategory.fallbackKey }
        )
    }
}
