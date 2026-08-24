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

    /// Minimum number of total logs before time-aware suggestions activate.
    static let activationThreshold = 5

    /// Computes the blended top categories for the current time bucket.
    ///
    /// Strategy:
    /// 1. Count `(category, bucket)` pairs from all non-archived entries.
    /// 2. For the current bucket, sort categories by frequency.
    /// 3. Fill `maxSlots` tiles: time-aware categories first, then global top-up.
    /// 4. If total logs < `activationThreshold`, return only global top categories.
    ///
    /// - Parameters:
    ///   - entries: All active (non-archived, non-pending) entries.
    ///   - categories: All SpendCategory objects (for name/emoji lookup).
    ///   - maxSlots: Maximum number of tiles to show (default 4).
    /// - Returns: An ordered array of category keys to display as tiles.
    static func blendedTopCategories(
        entries: [Entry],
        categories: [SpendCategory],
        maxSlots: Int = 4
    ) -> [String] {
        // Need enough data before time-aware kicks in.
        guard entries.count >= activationThreshold else {
            return globalTopCategories(entries: entries, categories: categories, limit: maxSlots)
        }

        let currentBucket = TimeBucket.forDate(.now)

        // Count (category, bucket) pairs.
        var bucketCounts: [String: Int] = [:]    // category key → count in current bucket
        var globalCounts: [String: Int] = [:]    // category key → total count across all buckets

        for entry in entries {
            let key = entry.category
            globalCounts[key, default: 0] += 1
            if TimeBucket.forDate(entry.date) == currentBucket {
                bucketCounts[key, default: 0] += 1
            }
        }

        // Sort categories by bucket frequency, then by global frequency as tiebreaker.
        let sortedByBucket = bucketCounts.sorted { a, b in
            if a.value != b.value { return a.value > b.value }
            return (globalCounts[a.key] ?? 0) > (globalCounts[b.key] ?? 0)
        }

        // Start with time-aware picks (exclude "other" unless it's the only option).
        var result: [String] = []
        for (key, _) in sortedByBucket {
            guard result.count < maxSlots else { break }
            if key != SpendCategory.fallbackKey || result.isEmpty {
                result.append(key)
            }
        }

        // Fill remaining slots with global top categories not already included.
        if result.count < maxSlots {
            let global = globalTopCategories(entries: entries, categories: categories, limit: maxSlots)
            for key in global {
                guard result.count < maxSlots else { break }
                if !result.contains(key) {
                    result.append(key)
                }
            }
        }

        return result
    }

    /// Pure global top categories by frequency (no time awareness).
    private static func globalTopCategories(
        entries: [Entry],
        categories: [SpendCategory],
        limit: Int
    ) -> [String] {
        var counts: [String: Int] = [:]
        for entry in entries {
            counts[entry.category, default: 0] += 1
        }
        return counts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }
}
