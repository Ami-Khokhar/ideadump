import Foundation

/// Divides the 24-hour day into 8 three-hour buckets for time-aware category
/// suggestions. The bucket is derived from the entry's date at query time — no
/// new model field is needed.
enum TimeBucket: Int, CaseIterable, Sendable {
    case earlyMorning = 0   // 12am – 3am
    case morning       = 1  // 3am – 6am
    case commute       = 2  // 6am – 9am
    case midday        = 3  // 9am – 12pm
    case afternoon     = 4  // 12pm – 3pm
    case lateAfternoon = 5  // 3pm – 6pm
    case evening       = 6  // 6pm – 9pm
    case night         = 7  // 9pm – 12am

    /// Returns the bucket for a given date.
    static func forDate(_ date: Date) -> TimeBucket {
        let hour = Calendar.current.component(.hour, from: date)
        return TimeBucket(rawValue: hour / 3) ?? .earlyMorning
    }

    /// Human-readable label for the bucket.
    var label: String {
        switch self {
        case .earlyMorning: return "Late Night"
        case .morning:      return "Early Morning"
        case .commute:      return "Commute"
        case .midday:       return "Midday"
        case .afternoon:    return "Afternoon"
        case .lateAfternoon: return "Late Afternoon"
        case .evening:      return "Evening"
        case .night:        return "Night"
        }
    }

    /// SF Symbol hint for the bucket.
    var icon: String {
        switch self {
        case .earlyMorning: return "moon.zzz"
        case .morning:      return "sunrise"
        case .commute:      return "car.fill"
        case .midday:       return "sun.max.fill"
        case .afternoon:    return "sun.min"
        case .lateAfternoon: return "sun.haze"
        case .evening:      return "sunset"
        case .night:        return "moon.stars"
        }
    }

    // MARK: - Time-Aware Category Learning

    /// Minimum number of windowed logs before time-aware suggestions activate.
    static let activationThreshold = 5
    /// Rolling window in days — only entries within this period influence suggestions.
    static let windowDays = 60
    /// Pseudo-observation count for the global prior in Bayesian blending.
    static let bayesianK = 3.0
    /// Pseudo-observations credited to a category the user has set a budget on.
    /// Setting a budget is a declared intent to log that category, so it enters the
    /// blend as evidence rather than as a special case. Sized just above a single
    /// incidental log: a budget outranks a category logged once, but two logs in the
    /// current bucket — or any real habit — win the slot back. That keeps a user with
    /// more budgets than slots from losing their genuinely frequent tiles.
    static let budgetIntentWeight = 1.5

    /// Computes the blended top categories for the current time bucket.
    ///
    /// Strategy:
    /// 1. Restrict to a 60-day rolling window so stale habits don't crowd out new ones.
    /// 2. Split entries into weekday / weekend to avoid surfacing commute categories
    ///    on Saturdays and leisure categories on Monday mornings.
    /// 3. Count (category, bucket) pairs from the matching partition.
    /// 4. Rank with a Bayesian blend: global-frequency prior (k=3 pseudo-observations)
    ///    + bucket evidence + budget intent. Low bucket counts stay anchored near the
    ///    global ranking instead of flipping tiles on a single log.
    /// 5. If windowed logs < activationThreshold, return plain global top categories.
    /// 6. With no windowed logs at all, seed the row from the category list itself —
    ///    the very first log has no history to rank, but still needs tiles, and a
    ///    budget set before that first log leads it.
    ///
    /// - Parameters:
    ///   - entries: All active (non-archived, non-pending) entries.
    ///   - categories: All SpendCategory objects (for name/emoji lookup).
    ///   - maxSlots: Maximum number of tiles to show (default 4).
    ///   - referenceDate: Point-in-time for bucket and weekday/weekend derivation (default .now).
    /// - Returns: An ordered array of category keys to display as tiles.
    static func blendedTopCategories(
        entries: [Entry],
        categories: [SpendCategory],
        maxSlots: Int = 4,
        referenceDate: Date = .now
    ) -> [String] {
        let calendar = Calendar.current
        let windowStart = calendar.date(byAdding: .day, value: -windowDays, to: referenceDate)!
        // The window is bounded at both ends. With only a lower bound, an entry
        // dated next week counted as evidence of a habit, so a single
        // future-dated log could reorder the tiles before it had happened.
        let windowedEntries = entries.filter { $0.date >= windowStart && $0.date <= referenceDate }

        guard windowedEntries.count >= activationThreshold else {
            return globalTopCategories(entries: windowedEntries, categories: categories, limit: maxSlots)
        }

        let currentBucket = TimeBucket.forDate(referenceDate)
        let todayIsWeekend = calendar.isDateInWeekend(referenceDate)

        var bucketCounts: [String: Int] = [:]
        var globalCounts: [String: Int] = [:]

        for entry in windowedEntries {
            let key = entry.category
            globalCounts[key, default: 0] += 1
            // Only count bucket matches from the same weekday/weekend partition.
            if calendar.isDateInWeekend(entry.date) == todayIsWeekend,
               TimeBucket.forDate(entry.date) == currentBucket {
                bucketCounts[key, default: 0] += 1
            }
        }

        // Bayesian blend: score = bucket evidence + global prior scaled to k pseudo-observations.
        // When bucket data is thin, the prior keeps the ranking close to the global top;
        // as bucket evidence accumulates it outweighs the prior naturally.
        let totalGlobal = max(1, globalCounts.values.reduce(0, +))
        // Deterministic final tie-break: display order, then key. Without it,
        // equal scores (e.g. an empty bucket collapsing everything to the prior)
        // sort by raw dictionary order and the tiles reshuffle every launch.
        let displayOrder = Dictionary(uniqueKeysWithValues: categories.map { ($0.key, $0.sortOrder) })

        func ranksHigher(_ lhs: String, than rhs: String, score lhsScore: Double, rhsScore: Double) -> Bool {
            if lhsScore != rhsScore { return lhsScore > rhsScore }
            let lhsOrder = displayOrder[lhs] ?? Int.max
            let rhsOrder = displayOrder[rhs] ?? Int.max
            if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
            return lhs < rhs
        }

        // Budgeted categories join the candidate set even with zero logs. Ranking only
        // what has already been logged is self-fulfilling: a category you just set a
        // budget on can never earn a tile, so you must dig through the picker to log
        // the one thing you explicitly said you wanted to track.
        let budgeted = budgetedKeys(in: categories)

        let scored = Set(globalCounts.keys).union(budgeted)
            .filter { $0 != SpendCategory.fallbackKey }
            .map { key -> (key: String, score: Double) in
                let bc = Double(bucketCounts[key] ?? 0)
                let gc = Double(globalCounts[key] ?? 0)
                let intent = budgeted.contains(key) ? budgetIntentWeight : 0
                return (key, bc + gc / Double(totalGlobal) * bayesianK + intent)
            }
            .sorted {
                ranksHigher($0.key, than: $1.key, score: $0.score, rhsScore: $1.score)
            }

        var result = Array(scored.prefix(maxSlots).map(\.key))

        // If no non-fallback categories exist, pass through the fallback.
        if result.isEmpty {
            return globalTopCategories(entries: windowedEntries, categories: categories, limit: maxSlots)
        }

        // Fill any remaining slots with global top categories not already present.
        if result.count < maxSlots {
            let global = globalTopCategories(entries: windowedEntries, categories: categories, limit: maxSlots)
            for key in global where !result.contains(key) {
                guard result.count < maxSlots else { break }
                result.append(key)
            }
        }

        return result
    }

    /// Keys of categories carrying a usable budget. The fallback is excluded because
    /// the capture row renders its own "Other" tile — surfacing it here duplicates it.
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

    /// Pure global top categories by frequency within the provided entry set, with
    /// budgets counted as `budgetIntentWeight` pseudo-logs on the same scale. With no
    /// entries at all every category becomes a zero-score candidate, so budgets lead
    /// and display order fills the rest.
    /// Ties break on display order, then key, so the result is deterministic.
    private static func globalTopCategories(
        entries: [Entry],
        categories: [SpendCategory],
        limit: Int
    ) -> [String] {
        var counts: [String: Int] = [:]
        for entry in entries {
            counts[entry.category, default: 0] += 1
        }
        let displayOrder = Dictionary(uniqueKeysWithValues: categories.map { ($0.key, $0.sortOrder) })

        let budgeted = budgetedKeys(in: categories)

        // Every category joins as a zero-score candidate so the row always offers
        // `limit` tiles. Filling only when nothing was logged made the row collapse
        // from four tiles to one the moment the first entry landed. They are only
        // candidates — scoring below still runs, so usage and budgets rank above
        // them and display order fills whatever slots are left over.
        let fill = categories.map(\.key).filter { $0 != SpendCategory.fallbackKey }

        return Set(counts.keys).union(budgeted).union(fill)
            .map { key -> (key: String, score: Double) in
                (key, Double(counts[key] ?? 0) + (budgeted.contains(key) ? budgetIntentWeight : 0))
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                let lhsOrder = displayOrder[lhs.key] ?? Int.max
                let rhsOrder = displayOrder[rhs.key] ?? Int.max
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return lhs.key < rhs.key
            }
            .prefix(limit)
            .map(\.key)
    }
}
