import XCTest
@testable import TapLog

final class TimeBucketTests: XCTestCase {

    // MARK: - Bucket Assignment

    func testHourZeroMapsToEarlyMorning() {
        let date = dateWithHour(0)
        XCTAssertEqual(TimeBucket.forDate(date), .earlyMorning)
    }

    func testHourTwoMapsToEarlyMorning() {
        let date = dateWithHour(2)
        XCTAssertEqual(TimeBucket.forDate(date), .earlyMorning)
    }

    func testHourThreeMapsToMorning() {
        let date = dateWithHour(3)
        XCTAssertEqual(TimeBucket.forDate(date), .morning)
    }

    func testHourEightMapsToCommute() {
        let date = dateWithHour(8)
        XCTAssertEqual(TimeBucket.forDate(date), .commute)
    }

    func testHourElevenMapsToMidday() {
        let date = dateWithHour(11)
        XCTAssertEqual(TimeBucket.forDate(date), .midday)
    }

    func testHourFourteenMapsToAfternoon() {
        let date = dateWithHour(14)
        XCTAssertEqual(TimeBucket.forDate(date), .afternoon)
    }

    func testHourSeventeenMapsToLateAfternoon() {
        let date = dateWithHour(17)
        XCTAssertEqual(TimeBucket.forDate(date), .lateAfternoon)
    }

    func testHourTwentyMapsToEvening() {
        let date = dateWithHour(20)
        XCTAssertEqual(TimeBucket.forDate(date), .evening)
    }

    func testHourTwentyThreeMapsToNight() {
        let date = dateWithHour(23)
        XCTAssertEqual(TimeBucket.forDate(date), .night)
    }

    func testAllBucketsAreCovered() {
        // Every hour 0–23 maps to exactly one of 8 buckets.
        var seen = Set<TimeBucket>()
        for hour in 0..<24 {
            let date = dateWithHour(hour)
            seen.insert(TimeBucket.forDate(date))
        }
        XCTAssertEqual(seen.count, 8, "all 8 buckets should be reachable")
    }

    // MARK: - Blended Top Categories

    func testBelowThresholdReturnsGlobalTop() {
        // Only 3 entries — below the 5-log activation threshold.
        let ref = weekdayAt(hour: 8)
        let entries = [
            makeEntry(category: "chai", hour: 8, referenceDay: ref),
            makeEntry(category: "chai", hour: 8, referenceDay: ref),
            makeEntry(category: "food", hour: 12, referenceDay: ref),
        ]
        let result = TimeBucket.blendedTopCategories(entries: entries, categories: [], maxSlots: 4, referenceDate: ref)
        XCTAssertEqual(result.first, "chai")
        XCTAssertEqual(result.count, 2)
    }

    func testAboveThresholdSurfacesBucketCategoryFirst() {
        // 10 entries: 5 chai at commute (8am), 5 food at afternoon (14pm).
        // Pinning referenceDate to the commute bucket means chai should rank first.
        let ref = weekdayAt(hour: 8)
        var entries: [Entry] = []
        for _ in 0..<5 { entries.append(makeEntry(category: "chai", hour: 8, referenceDay: ref)) }
        for _ in 0..<5 { entries.append(makeEntry(category: "food", hour: 14, referenceDay: ref)) }

        let result = TimeBucket.blendedTopCategories(entries: entries, categories: [], maxSlots: 4, referenceDate: ref)
        XCTAssertEqual(result.first, "chai", "chai dominates the commute bucket so it should rank first")
        XCTAssertTrue(result.contains("food"), "food fills the remaining slot via global top-up")
    }

    func testBothCategoriesAppearRegardlessOfCurrentBucket() {
        // 8 entries split between two buckets — both categories should appear in the result.
        let ref = weekdayAt(hour: 8)
        var entries: [Entry] = []
        for _ in 0..<4 { entries.append(makeEntry(category: "chai", hour: 8, referenceDay: ref)) }
        for _ in 0..<4 { entries.append(makeEntry(category: "food", hour: 14, referenceDay: ref)) }

        let result = TimeBucket.blendedTopCategories(entries: entries, categories: [], maxSlots: 4, referenceDate: ref)
        XCTAssertEqual(result.count, 2, "only 2 distinct categories exist")
        XCTAssertTrue(result.contains("chai"))
        XCTAssertTrue(result.contains("food"))
    }

    func testExcludesFallbackFromTimeAwareUnlessOnlyOption() {
        // 6 entries all in "other" — fallback should still surface since it's the only category.
        let ref = weekdayAt(hour: 8)
        let entries = (0..<6).map { _ in makeEntry(category: SpendCategory.fallbackKey, hour: 8, referenceDay: ref) }
        let result = TimeBucket.blendedTopCategories(entries: entries, categories: [], maxSlots: 4, referenceDate: ref)
        XCTAssertEqual(result.first, SpendCategory.fallbackKey)
    }

    func testMaxSlotsRespected() {
        // 10 entries across 5 categories — capped at maxSlots=3.
        let ref = weekdayAt(hour: 8)
        let cats = ["chai", "food", "metro", "lunch", "shopping"]
        var entries: [Entry] = []
        for cat in cats {
            for _ in 0..<2 { entries.append(makeEntry(category: cat, hour: 8, referenceDay: ref)) }
        }
        let result = TimeBucket.blendedTopCategories(entries: entries, categories: [], maxSlots: 3, referenceDate: ref)
        XCTAssertEqual(result.count, 3, "should cap at maxSlots")
    }

    // MARK: - 60-day rolling window

    func testEntriesOlderThan60DaysAreIgnored() {
        // 4 chai entries from 90 days ago (outside window) + 5 food entries from today.
        // Only the food entries count; chai should not appear.
        let ref = weekdayAt(hour: 8)
        let old = Calendar.current.date(byAdding: .day, value: -90, to: ref)!
        var entries: [Entry] = []
        for _ in 0..<4 { entries.append(makeEntry(category: "chai", hour: 8, on: old)) }
        for _ in 0..<5 { entries.append(makeEntry(category: "food", hour: 8, referenceDay: ref)) }

        let result = TimeBucket.blendedTopCategories(entries: entries, categories: [], maxSlots: 4, referenceDate: ref)
        XCTAssertFalse(result.contains("chai"), "entries older than 60 days must not influence ranking")
        XCTAssertTrue(result.contains("food"))
    }

    func testEntriesExactlyAt60DaysAreIncluded() {
        // Entry right at the 60-day boundary should count toward the windowed total.
        let ref = weekdayAt(hour: 8)
        let boundary = Calendar.current.date(byAdding: .day, value: -60, to: ref)!
        var entries: [Entry] = []
        entries.append(makeEntry(category: "chai", hour: 8, on: boundary))
        for _ in 0..<4 { entries.append(makeEntry(category: "food", hour: 8, referenceDay: ref)) }

        let result = TimeBucket.blendedTopCategories(entries: entries, categories: [], maxSlots: 4, referenceDate: ref)
        // 5 total windowed entries → above threshold; chai should appear.
        XCTAssertTrue(result.contains("chai"))
    }

    // MARK: - Weekday / weekend partitioning

    func testWeekdayBucketCountsIgnoreWeekendEntries() {
        // chai logged heavily on weekends; food logged on weekdays.
        // When the reference date is a weekday, food should rank first in the commute bucket.
        let weekday = nextWeekday(hour: 8)
        let weekend = nextWeekend(hour: 8)
        var entries: [Entry] = []
        for _ in 0..<8 { entries.append(makeEntry(category: "chai", hour: 8, on: weekend)) }
        for _ in 0..<3 { entries.append(makeEntry(category: "food", hour: 8, on: weekday)) }

        let result = TimeBucket.blendedTopCategories(entries: entries, categories: [], maxSlots: 4, referenceDate: weekday)
        XCTAssertEqual(result.first, "food", "weekday bucket should rank food first, not weekend chai")
    }

    func testWeekendBucketCountsIgnoreWeekdayEntries() {
        // metro logged heavily on weekdays; shopping logged on weekends.
        // When the reference date is a weekend, shopping should rank first.
        let weekday = nextWeekday(hour: 8)
        let weekend = nextWeekend(hour: 8)
        var entries: [Entry] = []
        for _ in 0..<8 { entries.append(makeEntry(category: "metro", hour: 8, on: weekday)) }
        for _ in 0..<3 { entries.append(makeEntry(category: "shopping", hour: 8, on: weekend)) }

        let result = TimeBucket.blendedTopCategories(entries: entries, categories: [], maxSlots: 4, referenceDate: weekend)
        XCTAssertEqual(result.first, "shopping", "weekend bucket should rank shopping first, not weekday metro")
    }

    // MARK: - Bayesian blending

    func testBayesianPriorPreventsFlipOnSingleBucketEntry() {
        // chai: 1 bucket entry, 1 global total.
        // food: 0 bucket entries, 4 global total.
        // Without prior, chai (bucket=1) would rank above food (bucket=0).
        // With k=3: chai score = 1 + (1/5)*3 = 1.6; food score = 0 + (4/5)*3 = 2.4 → food wins.
        let ref = weekdayAt(hour: 8)
        var entries: [Entry] = []
        entries.append(makeEntry(category: "chai", hour: 8, referenceDay: ref))    // 1 bucket, 1 global
        for _ in 0..<4 { entries.append(makeEntry(category: "food", hour: 14, referenceDay: ref)) } // 0 bucket, 4 global

        let result = TimeBucket.blendedTopCategories(entries: entries, categories: [], maxSlots: 4, referenceDate: ref)
        XCTAssertEqual(result.first, "food", "global prior should outweigh a single stray bucket hit")
    }

    // MARK: - Deterministic ordering

    func testEqualScoresBreakTiesOnDisplayOrderThenKey() {
        // Mirrors the seed data: chai 3, food 3, shopping 2, and transport /
        // fun / bills / health 1 each — every entry in bucket 0 while the
        // reference sits in bucket 7, so all scores collapse to the global
        // prior (chai/food tie at 0.75, four categories tie at 0.25 for the
        // last slot). The old sort left those ties to dictionary iteration
        // order, reshuffling the tiles between launches.
        let ref = weekdayAt(hour: 21)
        let seedOrder: [(String, Int)] = [
            ("chai", 0), ("food", 1), ("transport", 2), ("shopping", 6),
            ("bills", 7), ("health", 9), ("fun", 10),
        ]
        let categories = seedOrder.map { SpendCategory(key: $0.0, name: $0.0, emoji: "•", sortOrder: $0.1) }

        var entries: [Entry] = []
        for _ in 0..<3 { entries.append(makeEntry(category: "chai", hour: 0, referenceDay: ref)) }
        for _ in 0..<3 { entries.append(makeEntry(category: "food", hour: 2, referenceDay: ref)) }
        for _ in 0..<2 { entries.append(makeEntry(category: "shopping", hour: 0, referenceDay: ref)) }
        for key in ["transport", "fun", "bills", "health"] {
            entries.append(makeEntry(category: key, hour: 2, referenceDay: ref))
        }

        let result = TimeBucket.blendedTopCategories(entries: entries, categories: categories, maxSlots: 4, referenceDate: ref)
        XCTAssertEqual(result, ["chai", "food", "shopping", "transport"])
    }

    func testBlendedTopCategoriesIsStableAcrossRepeatedCalls() {
        // Same inputs must yield byte-identical output on every call — muscle
        // memory depends on tiles never moving without a data change.
        let ref = weekdayAt(hour: 8)
        var entries: [Entry] = []
        for _ in 0..<3 { entries.append(makeEntry(category: "chai", hour: 8, referenceDay: ref)) }
        for _ in 0..<3 { entries.append(makeEntry(category: "food", hour: 14, referenceDay: ref)) }
        for _ in 0..<2 { entries.append(makeEntry(category: "metro", hour: 20, referenceDay: ref)) }

        let first = TimeBucket.blendedTopCategories(entries: entries, categories: [], maxSlots: 4, referenceDate: ref)
        for _ in 0..<50 {
            XCTAssertEqual(
                TimeBucket.blendedTopCategories(entries: entries, categories: [], maxSlots: 4, referenceDate: ref),
                first
            )
        }
    }

    func testGlobalTopTieBreaksOnKeyWhenNoCategoriesProvided() {
        // Below the activation threshold the plain global ranking runs; equal
        // counts must fall back to alphabetical key order, not hash order.
        let ref = weekdayAt(hour: 8)
        let entries = [
            makeEntry(category: "zeta", hour: 8, referenceDay: ref),
            makeEntry(category: "alpha", hour: 12, referenceDay: ref),
            makeEntry(category: "alpha", hour: 14, referenceDay: ref),
            makeEntry(category: "zeta", hour: 16, referenceDay: ref),
        ]
        let result = TimeBucket.blendedTopCategories(entries: entries, categories: [], maxSlots: 4, referenceDate: ref)
        XCTAssertEqual(result.first, "alpha")
        XCTAssertEqual(result[1], "zeta")
    }

    // MARK: - Helpers

    private func weekdayAt(hour: Int) -> Date {
        nextWeekday(hour: hour)
    }

    /// Returns the most recent (or today's) weekday date at the given hour.
    private func nextWeekday(hour: Int) -> Date {
        let cal = Calendar.current
        var date = Date()
        for _ in 0..<7 {
            if !cal.isDateInWeekend(date) {
                return setHour(hour, on: date)
            }
            date = cal.date(byAdding: .day, value: -1, to: date)!
        }
        return setHour(hour, on: date)
    }

    /// Returns the most recent (or today's) weekend date at the given hour.
    private func nextWeekend(hour: Int) -> Date {
        let cal = Calendar.current
        var date = Date()
        for _ in 0..<7 {
            if cal.isDateInWeekend(date) {
                return setHour(hour, on: date)
            }
            date = cal.date(byAdding: .day, value: -1, to: date)!
        }
        return setHour(hour, on: date)
    }

    private func setHour(_ hour: Int, on date: Date) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        comps.hour = hour
        comps.minute = 15
        comps.second = 0
        return Calendar.current.date(from: comps)!
    }

    private func dateWithHour(_ hour: Int) -> Date {
        setHour(hour, on: Date())
    }

    /// Entry dated on the same calendar day as `referenceDay` at the given hour.
    private func makeEntry(category: String, hour: Int, referenceDay: Date) -> Entry {
        makeEntry(category: category, hour: hour, on: referenceDay)
    }

    /// Entry at a specific date with the given hour component.
    private func makeEntry(category: String, hour: Int, on date: Date) -> Entry {
        let entryDate = setHour(hour, on: date)
        return Entry(amount: Decimal(10), category: category, note: nil, date: entryDate)
    }
}
