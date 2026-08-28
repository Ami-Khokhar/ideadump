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
            makeEntry(category: "food", hour: 12, on: weekEarlier(ref)),
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
        for _ in 0..<5 { entries.append(makeEntry(category: "food", hour: 14, on: weekEarlier(ref))) }

        let result = TimeBucket.blendedTopCategories(entries: entries, categories: [], maxSlots: 4, referenceDate: ref)
        XCTAssertEqual(result.first, "chai", "chai dominates the commute bucket so it should rank first")
        XCTAssertTrue(result.contains("food"), "food fills the remaining slot via global top-up")
    }

    func testBothCategoriesAppearRegardlessOfCurrentBucket() {
        // 8 entries split between two buckets — both categories should appear in the result.
        let ref = weekdayAt(hour: 8)
        var entries: [Entry] = []
        for _ in 0..<4 { entries.append(makeEntry(category: "chai", hour: 8, referenceDay: ref)) }
        for _ in 0..<4 { entries.append(makeEntry(category: "food", hour: 14, on: weekEarlier(ref))) }

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
        // The weekend entries sit before the reference weekday: nextWeekend walks
        // back from *today*, so on a weekend run it would land after the reference
        // and the bounded window would silently drop the whole chai partition.
        let weekday = nextWeekday(hour: 8)
        let weekend = weekendBefore(weekday)
        var entries: [Entry] = []
        for _ in 0..<8 { entries.append(makeEntry(category: "chai", hour: 8, on: weekend)) }
        for _ in 0..<3 { entries.append(makeEntry(category: "food", hour: 8, on: weekday)) }

        let result = TimeBucket.blendedTopCategories(entries: entries, categories: [], maxSlots: 4, referenceDate: weekday)
        XCTAssertEqual(result.first, "food", "weekday bucket should rank food first, not weekend chai")
    }

    func testWeekendBucketCountsIgnoreWeekdayEntries() {
        // metro logged heavily on weekdays; shopping logged on weekends.
        // When the reference date is a weekend, shopping should rank first.
        // The weekday entries sit before the reference weekend for the same
        // reason as above — on a weekday run they would post-date the reference.
        let weekend = nextWeekend(hour: 8)
        let weekday = weekdayBefore(weekend)
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
        for _ in 0..<4 { entries.append(makeEntry(category: "food", hour: 14, on: weekEarlier(ref))) } // 0 bucket, 4 global

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
        for _ in 0..<3 { entries.append(makeEntry(category: "food", hour: 14, on: weekEarlier(ref))) }
        for _ in 0..<2 { entries.append(makeEntry(category: "metro", hour: 20, on: weekEarlier(ref))) }

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
            makeEntry(category: "alpha", hour: 12, on: weekEarlier(ref)),
            makeEntry(category: "alpha", hour: 14, on: weekEarlier(ref)),
            makeEntry(category: "zeta", hour: 16, on: weekEarlier(ref)),
        ]
        let result = TimeBucket.blendedTopCategories(entries: entries, categories: [], maxSlots: 4, referenceDate: ref)
        // Whole-array equality, not `result[1]`: a subscript on a short result
        // traps and takes down the entire test process instead of failing here.
        XCTAssertEqual(result, ["alpha", "zeta"])
    }

    // MARK: - Cold start

    func testEmptyEntriesReturnDefaultCategoriesBySortOrder() {
        // A fresh install has no history to rank. Returning nothing left the very
        // first log with an empty tile row, so the display order seeds it instead.
        let ref = weekdayAt(hour: 8)
        let result = TimeBucket.blendedTopCategories(
            entries: [],
            categories: seedCategories(),
            maxSlots: 4,
            referenceDate: ref
        )
        XCTAssertEqual(result, ["chai", "food", "transport", "metro"])
    }

    func testEmptyEntriesExcludeFallbackFromDefaultSet() {
        // The capture row renders its own "Other" tile; seeding it here duplicates it.
        let ref = weekdayAt(hour: 8)
        let categories = [
            SpendCategory(key: SpendCategory.fallbackKey, name: "Other", emoji: "📦", sortOrder: 0),
            SpendCategory(key: "chai", name: "Chai", emoji: "☕️", sortOrder: 1),
        ]
        let result = TimeBucket.blendedTopCategories(entries: [], categories: categories, maxSlots: 4, referenceDate: ref)
        XCTAssertEqual(result, ["chai"])
    }

    func testEmptyEntriesCapDefaultSetAtMaxSlots() {
        let ref = weekdayAt(hour: 8)
        let result = TimeBucket.blendedTopCategories(
            entries: [],
            categories: seedCategories(),
            maxSlots: 2,
            referenceDate: ref
        )
        XCTAssertEqual(result, ["chai", "food"])
    }

    // MARK: - Budget intent

    func testBudgetedCategoryWithNoLogsStillEarnsATile() {
        // The chicken-and-egg case from the simulator: a ₹300/month budget on chai
        // that has never been logged. Frequency alone can never surface it.
        let ref = weekdayAt(hour: 8)
        let categories = [
            SpendCategory(key: "chai", name: "Chai", emoji: "☕️", sortOrder: 0,
                          budgetTarget: 300, budgetPeriod: .monthly),
            SpendCategory(key: "food", name: "Food", emoji: "🍽️", sortOrder: 1),
        ]
        let entries = (0..<6).map { _ in makeEntry(category: "food", hour: 8, referenceDay: ref) }

        let result = TimeBucket.blendedTopCategories(entries: entries, categories: categories, maxSlots: 4, referenceDate: ref)
        XCTAssertTrue(result.contains("chai"), "a budgeted category must be eligible with zero logs")
        XCTAssertEqual(result.first, "food", "six logs in this bucket still outrank a never-logged budget")
    }

    func testBudgetedCategoryLeadsColdStartWhenSortOrderIsOutsideTheRow() {
        // The simulator repro: fresh install, zero entries, first budget set on a
        // category that sits outside the first four by display order. Ranking the
        // cold-start row on sortOrder alone buried it forever.
        let ref = weekdayAt(hour: 8)
        let categories = fullSeedCategories()
        setBudget(on: categories, key: "snacks", target: 50, period: .weekly)

        let result = TimeBucket.blendedTopCategories(entries: [], categories: categories, maxSlots: 4, referenceDate: ref)
        XCTAssertEqual(result, ["snacks", "chai", "food", "transport"])
    }

    func testColdStartCapsBudgetsAtMaxSlotsDeterministically() {
        // Six budgets, four slots: the four lowest sortOrder budgets win and the
        // order never changes between calls.
        let ref = weekdayAt(hour: 8)
        let categories = fullSeedCategories()
        for key in ["snacks", "bills", "groceries", "shopping", "metro", "lunch"] {
            setBudget(on: categories, key: key, target: 100, period: .monthly)
        }

        let result = TimeBucket.blendedTopCategories(entries: [], categories: categories, maxSlots: 4, referenceDate: ref)
        XCTAssertEqual(result, ["metro", "lunch", "groceries", "shopping"])
        for _ in 0..<50 {
            XCTAssertEqual(
                TimeBucket.blendedTopCategories(entries: [], categories: categories, maxSlots: 4, referenceDate: ref),
                result
            )
        }
    }

    func testColdStartWithoutBudgetsIsUnchanged() {
        // No budgets anywhere: the row is still the plain display-order default set.
        let ref = weekdayAt(hour: 8)
        let result = TimeBucket.blendedTopCategories(
            entries: [],
            categories: fullSeedCategories(),
            maxSlots: 4,
            referenceDate: ref
        )
        XCTAssertEqual(result, ["chai", "food", "transport", "metro"])
    }

    func testBudgetedCategorySurfacesBelowActivationThreshold() {
        // Same repro on a near-fresh install: only 2 logs, so the plain global
        // ranking runs. It has to honor budgets too or the tile never appears.
        let ref = weekdayAt(hour: 8)
        let categories = [
            SpendCategory(key: "chai", name: "Chai", emoji: "☕️", sortOrder: 0,
                          budgetTarget: 300, budgetPeriod: .monthly),
            SpendCategory(key: "food", name: "Food", emoji: "🍽️", sortOrder: 1),
        ]
        let entries = (0..<2).map { _ in makeEntry(category: "food", hour: 8, referenceDay: ref) }

        let result = TimeBucket.blendedTopCategories(entries: entries, categories: categories, maxSlots: 4, referenceDate: ref)
        XCTAssertEqual(result, ["food", "chai"])
    }

    func testBudgetWithoutPeriodIsNotTreatedAsIntent() {
        // A target with no period is an incomplete budget — CategoryManageView
        // requires both — so it must not be weighted as intent. Every category
        // now fills a slot, so absence no longer proves that; rank does. A real
        // budget scores 1.5 and would outrank the single snacks log, so chai
        // landing *below* snacks is what shows it earned no boost.
        let ref = weekdayAt(hour: 8)
        let categories = [
            SpendCategory(key: "chai", name: "Chai", emoji: "☕️", sortOrder: 0, budgetTarget: 300),
            SpendCategory(key: "food", name: "Food", emoji: "🍽️", sortOrder: 1),
            SpendCategory(key: "snacks", name: "Snacks", emoji: "🍿", sortOrder: 2),
        ]
        var entries = (0..<6).map { _ in makeEntry(category: "food", hour: 8, referenceDay: ref) }
        entries.append(makeEntry(category: "snacks", hour: 8, referenceDay: ref))

        let result = TimeBucket.blendedTopCategories(entries: entries, categories: categories, maxSlots: 4, referenceDate: ref)
        XCTAssertEqual(result, ["food", "snacks", "chai"])
    }

    func testEveryCategoryFillsTheRowOnceSomethingIsLogged() {
        // The row must not shrink as soon as the first entry lands: logging one
        // category used to collapse it from four tiles to one.
        let ref = weekdayAt(hour: 8)
        let categories = seedCategories()
        let entries = [makeEntry(category: "chai", hour: 8, referenceDay: ref)]

        let result = TimeBucket.blendedTopCategories(entries: entries, categories: categories, maxSlots: 4, referenceDate: ref)
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result.first, "chai")
    }

    func testHeavyUsageOutranksNeverLoggedBudget() {
        // Two slots, three contenders. Budgets are weighted evidence, not a pin —
        // a user with more budgets than slots keeps their real habits on screen.
        let ref = weekdayAt(hour: 8)
        let categories = [
            SpendCategory(key: "chai", name: "Chai", emoji: "☕️", sortOrder: 0,
                          budgetTarget: 300, budgetPeriod: .monthly),
            SpendCategory(key: "food", name: "Food", emoji: "🍽️", sortOrder: 1),
            SpendCategory(key: "metro", name: "Metro", emoji: "🚇", sortOrder: 2),
        ]
        var entries: [Entry] = []
        for _ in 0..<6 { entries.append(makeEntry(category: "food", hour: 8, referenceDay: ref)) }
        for _ in 0..<4 { entries.append(makeEntry(category: "metro", hour: 8, referenceDay: ref)) }

        let result = TimeBucket.blendedTopCategories(entries: entries, categories: categories, maxSlots: 2, referenceDate: ref)
        XCTAssertEqual(result, ["food", "metro"])
        XCTAssertFalse(result.contains("chai"), "a never-logged budget must not displace heavy usage")
    }

    func testBudgetOutranksASingleIncidentalLog() {
        // The calibration point: gift scores 1 + (1/10)*3 = 1.3, below the 1.5
        // credited to a declared budget. chai sorts later than gift, so score —
        // not display order — is what puts it in the second slot.
        let ref = weekdayAt(hour: 8)
        let categories = [
            SpendCategory(key: "gift", name: "Gift", emoji: "🎁", sortOrder: 1),
            SpendCategory(key: "food", name: "Food", emoji: "🍽️", sortOrder: 2),
            SpendCategory(key: "chai", name: "Chai", emoji: "☕️", sortOrder: 5,
                          budgetTarget: 300, budgetPeriod: .monthly),
        ]
        var entries: [Entry] = []
        for _ in 0..<9 { entries.append(makeEntry(category: "food", hour: 14, on: weekEarlier(ref))) }
        entries.append(makeEntry(category: "gift", hour: 8, referenceDay: ref))

        let result = TimeBucket.blendedTopCategories(entries: entries, categories: categories, maxSlots: 2, referenceDate: ref)
        XCTAssertEqual(result, ["food", "chai"])
    }

    func testBudgetBlendIsStableAcrossRepeatedCalls() {
        // Budgets widen the candidate set to a Set union — the sort must still be
        // total, or tiles reshuffle between launches with no data change.
        let ref = weekdayAt(hour: 8)
        let categories = seedCategories()
        setBudget(on: categories, key: "chai", target: 300, period: .monthly)
        setBudget(on: categories, key: "metro", target: 900, period: .weekly)

        var entries: [Entry] = []
        for _ in 0..<3 { entries.append(makeEntry(category: "food", hour: 8, referenceDay: ref)) }
        for _ in 0..<3 { entries.append(makeEntry(category: "shopping", hour: 14, on: weekEarlier(ref))) }
        for _ in 0..<2 { entries.append(makeEntry(category: "transport", hour: 20, on: weekEarlier(ref))) }

        let first = TimeBucket.blendedTopCategories(entries: entries, categories: categories, maxSlots: 4, referenceDate: ref)
        XCTAssertEqual(first.count, 4)
        for _ in 0..<50 {
            XCTAssertEqual(
                TimeBucket.blendedTopCategories(entries: entries, categories: categories, maxSlots: 4, referenceDate: ref),
                first
            )
        }
    }

    // MARK: - Helpers

    /// The full seed list in its shipped display order, plus the fallback.
    private func fullSeedCategories() -> [SpendCategory] {
        let seeds: [(String, Int)] = [
            ("chai", 0), ("food", 1), ("transport", 2), ("metro", 3), ("lunch", 4),
            ("groceries", 5), ("shopping", 6), ("bills", 7), ("snacks", 8),
            (SpendCategory.fallbackKey, 12),
        ]
        return seeds.map { SpendCategory(key: $0.0, name: $0.0, emoji: "•", sortOrder: $0.1) }
    }

    /// SpendCategory is a reference type, so this mutates the object the array holds.
    private func setBudget(on categories: [SpendCategory], key: String, target: Decimal, period: BudgetPeriod) {
        guard let category = categories.first(where: { $0.key == key }) else {
            XCTFail("no category named \(key)")
            return
        }
        category.budgetTarget = target
        category.budgetPeriod = period
    }

    /// Five categories in seed display order plus the fallback.
    private func seedCategories() -> [SpendCategory] {
        [
            SpendCategory(key: "chai", name: "Chai", emoji: "☕️", sortOrder: 0),
            SpendCategory(key: "food", name: "Food", emoji: "🍽️", sortOrder: 1),
            SpendCategory(key: "transport", name: "Transport", emoji: "🚌", sortOrder: 2),
            SpendCategory(key: "metro", name: "Metro", emoji: "🚇", sortOrder: 3),
            SpendCategory(key: "shopping", name: "Shopping", emoji: "🛍️", sortOrder: 4),
            SpendCategory(key: SpendCategory.fallbackKey, name: "Other", emoji: "📦", sortOrder: 99),
        ]
    }

    /// The same weekday one week earlier. Entries in a *different* time bucket
    /// have to sit in the past, not later the same day: a later hour on the
    /// reference day is future-dated relative to the reference date, and
    /// suggestions are ranked only on spend that has happened.
    private func weekEarlier(_ date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -7, to: date)!
    }

    /// The closest weekend day strictly before `date`. The hour component is
    /// irrelevant — makeEntry re-stamps the hour on whatever day this returns.
    private func weekendBefore(_ date: Date) -> Date {
        let cal = Calendar.current
        var day = cal.date(byAdding: .day, value: -1, to: date)!
        while !cal.isDateInWeekend(day) {
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return day
    }

    /// The closest weekday strictly before `date`.
    private func weekdayBefore(_ date: Date) -> Date {
        let cal = Calendar.current
        var day = cal.date(byAdding: .day, value: -1, to: date)!
        while cal.isDateInWeekend(day) {
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return day
    }

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
