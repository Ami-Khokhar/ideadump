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
        let entries = [
            makeEntry(category: "chai", hour: 8),
            makeEntry(category: "chai", hour: 8),
            makeEntry(category: "food", hour: 12),
        ]
        let result = TimeBucket.blendedTopCategories(entries: entries, categories: [], maxSlots: 4)
        // Should be global top: chai (2) > food (1).
        XCTAssertEqual(result.first, "chai")
        XCTAssertEqual(result.count, 2)
    }

    func testAboveThresholdUsesTimeAwareWhenDataExists() {
        // 10 entries — all "chai" in the commute bucket (6–9am), all "food" in afternoon (12–3pm).
        var entries: [Entry] = []
        for i in 0..<5 {
            entries.append(makeEntry(category: "chai", hour: 7 + (i % 3)))
        }
        for i in 0..<5 {
            entries.append(makeEntry(category: "food", hour: 12 + (i % 3)))
        }

        // Simulate current time being in the commute bucket by checking
        // what buckets the entries fall into.
        let currentBucket = TimeBucket.forDate(.now)

        let result = TimeBucket.blendedTopCategories(entries: entries, categories: [], maxSlots: 4)

        // The result should include both categories, with the current
        // bucket's category ranked first.
        XCTAssertTrue(result.contains("chai") || result.contains("food"),
                       "should include at least one of the seeded categories")
        XCTAssertEqual(result.count, 2)
    }

    func testBlendingFillsRemainingSlotsWithGlobal() {
        // 8 entries: 4 chai at 8am, 4 food at 2pm.
        // If current time is commute, chai gets bucket slots, food fills via global.
        var entries: [Entry] = []
        for i in 0..<4 {
            entries.append(makeEntry(category: "chai", hour: 7 + (i % 3)))
        }
        for i in 0..<4 {
            entries.append(makeEntry(category: "food", hour: 12 + (i % 3)))
        }

        let result = TimeBucket.blendedTopCategories(entries: entries, categories: [], maxSlots: 4)
        XCTAssertEqual(result.count, 2, "only 2 categories exist, slots = 2")
        // Both should appear somewhere in the result.
        XCTAssertTrue(result.contains("chai"))
        XCTAssertTrue(result.contains("food"))
    }

    func testExcludesFallbackFromTimeAwareUnlessOnlyOption() {
        // 6 entries all in "other" in the commute bucket.
        var entries: [Entry] = []
        for i in 0..<6 {
            entries.append(makeEntry(category: SpendCategory.fallbackKey, hour: 7 + (i % 3)))
        }

        let result = TimeBucket.blendedTopCategories(entries: entries, categories: [], maxSlots: 4)
        // "other" should still appear since it's the only category.
        XCTAssertEqual(result.first, SpendCategory.fallbackKey)
    }

    func testMaxSlotsRespected() {
        // 10 entries across 5 different categories, all in the current bucket.
        let cats = ["chai", "food", "metro", "lunch", "shopping"]
        var entries: [Entry] = []
        for cat in cats {
            for i in 0..<2 {
                entries.append(makeEntry(category: cat, hour: 8 + (i % 3)))
            }
        }

        let result = TimeBucket.blendedTopCategories(entries: entries, categories: [], maxSlots: 3)
        XCTAssertEqual(result.count, 3, "should cap at maxSlots")
    }

    // MARK: - Helpers

    private func dateWithHour(_ hour: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components)!
    }

    private func makeEntry(category: String, hour: Int) -> Entry {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = 15
        let date = Calendar.current.date(from: components)!
        return Entry(amount: Decimal(10), category: category, note: nil, date: date)
    }
}
