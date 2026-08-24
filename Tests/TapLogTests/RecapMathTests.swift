import XCTest
@testable import TapLog

/// Deterministic coverage for the weekly recap math, using a fixed UTC calendar.
final class RecapMathTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday — matches the app's Monday-first week
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// 2026-08-17 is a Monday; the reference "now" is that Wednesday noon.
    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private var now: Date { date(2026, 8, 19) } // Wednesday

    private func makeEntry(_ amount: Decimal, on date: Date, category: String = "chai") -> Entry {
        Entry(amount: amount, category: category, date: date)
    }

    // MARK: - splitWeeks

    func testSplitsCurrentAndPreviousWeek() {
        let entries = [
            makeEntry(10, on: date(2026, 8, 17)), // this Monday
            makeEntry(20, on: now),               // this Wednesday
            makeEntry(15, on: date(2026, 8, 14)), // last Friday
            makeEntry(99, on: date(2026, 8, 3)),  // two weeks ago — ignored by both buckets
        ]
        let split = RecapMath.splitWeeks(entries, calendar: calendar, now: now)
        XCTAssertEqual(split.thisWeek.count, 2)
        XCTAssertEqual(split.lastWeek.count, 1)
        XCTAssertEqual(split.thisWeek.reduce(0) { $0 + $1.amount }, 30)
        XCTAssertEqual(split.lastWeek.reduce(0) { $0 + $1.amount }, 15)
    }

    func testEntryAtWeekBoundaryBelongsToNewWeek() {
        let mondayMidnight = date(2026, 8, 17, hour: 0)
        let sundayNight = date(2026, 8, 16, hour: 23)
        let split = RecapMath.splitWeeks(
            [makeEntry(5, on: mondayMidnight), makeEntry(7, on: sundayNight)],
            calendar: calendar, now: now
        )
        XCTAssertEqual(split.thisWeek.reduce(0) { $0 + $1.amount }, 5)
        XCTAssertEqual(split.lastWeek.reduce(0) { $0 + $1.amount }, 7)
    }

    // MARK: - dailyTotals (index 0 = Monday)

    func testDailyTotalsBucketByDayOfWeek() {
        let entries = [
            makeEntry(10, on: date(2026, 8, 17)),           // Mon → index 0
            makeEntry(Decimal(string: "7.25")!, on: now),   // Wed → index 2
            makeEntry(3, on: date(2026, 8, 24)),            // next Monday — outside the week
            makeEntry(4, on: date(2026, 8, 14)),            // last Friday — outside the week
        ]
        let totals = RecapMath.dailyTotals(entries, calendar: calendar, now: now)
        XCTAssertEqual(totals.count, 7)
        XCTAssertEqual(totals[0], 10)
        XCTAssertEqual(totals[2], Decimal(string: "7.25")!)
        XCTAssertEqual(totals.reduce(0) { $0 + $1 }, Decimal(string: "17.25")!)
    }

    // MARK: - totals(byCategory)

    func testCategoryTotalsMergeEntriesByKey() {
        let entries = [
            makeEntry(10, on: now, category: "chai"),
            makeEntry(5, on: now, category: "chai"),
            makeEntry(40, on: now, category: "food"),
        ]
        XCTAssertEqual(RecapMath.totals(byCategory: entries), ["chai": 15, "food": 40])
    }

    func testEmptyInputsAreSafe() {
        XCTAssertTrue(RecapMath.splitWeeks([], calendar: calendar, now: now).thisWeek.isEmpty)
        XCTAssertEqual(RecapMath.dailyTotals([], calendar: calendar, now: now), Array(repeating: 0, count: 7))
        XCTAssertTrue(RecapMath.totals(byCategory: []).isEmpty)
    }

    // MARK: - todayIndex

    func testTodayIndexIsMondayFirst() {
        XCTAssertEqual(RecapMath.todayIndex(calendar: calendar, now: date(2026, 8, 17)), 0) // Mon
        XCTAssertEqual(RecapMath.todayIndex(calendar: calendar, now: now), 2)               // Wed
        XCTAssertEqual(RecapMath.todayIndex(calendar: calendar, now: date(2026, 8, 23)), 6) // Sun
    }
}
