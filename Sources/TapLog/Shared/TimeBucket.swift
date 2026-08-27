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

    /// Computes the blended top categories for the current time bucket.
    ///
    /// Strategy:
    /// 1. Restrict to a 60-day rolling window so stale habits don't crowd out new ones.
    /// 2. Split entries into weekday / weekend to avoid surfacing commute categories
    ///    on Saturdays and leisure categories on Monday mornings.
    /// 3. Count (category, bucket) pairs from the matching partition.
    /// 4. Rank with a Bayesian blend: global-frequency prior (k=3 pseudo-observations)
    ///    + bucket evidence. Low bucket counts stay anchored near the global ranking
    ///    instead of flipping tiles on a single log.
    /// 5. If windowed logs < activationThreshold, return plain global top categories.
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
        let windowedEntries = entries.filter { $0.date >= windowStart }

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

        let scored = globalCounts.keys
            .filter { $0 != SpendCategory.fallbackKey }
            .map { key -> (key: String, score: Double) in
                let bc = Double(bucketCounts[key] ?? 0)
                let gc = Double(globalCounts[key] ?? 0)
                return (key, bc + gc / Double(totalGlobal) * bayesianK)
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

    /// Pure global top categories by frequency within the provided entry set.
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
        return counts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                let lhsOrder = displayOrder[lhs.key] ?? Int.max
                let rhsOrder = displayOrder[rhs.key] ?? Int.max
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return lhs.key < rhs.key
            }
            .prefix(limit)
            .map(\.key)
    }
}
