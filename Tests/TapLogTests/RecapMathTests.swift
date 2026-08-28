import XCTest
@testable import TapLog

/// Deterministic coverage for the weekly recap math, using fixed UTC calendars.
final class RecapMathTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday — matches the app's Monday-first week
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    /// India/en_US-style Sunday-first week.
    private var sundayFirstCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
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

    // MARK: - monthWeekIndex

    func testMonthWeekIndexCountsSevenDayBlocksFromTheFirst() {
        let monthStart = date(2026, 8, 1)
        XCTAssertEqual(RecapMath.monthWeekIndex(for: date(2026, 8, 1), monthStart: monthStart, calendar: calendar), 0)
        XCTAssertEqual(RecapMath.monthWeekIndex(for: date(2026, 8, 7), monthStart: monthStart, calendar: calendar), 0)
        XCTAssertEqual(RecapMath.monthWeekIndex(for: date(2026, 8, 8), monthStart: monthStart, calendar: calendar), 1)
        XCTAssertEqual(RecapMath.monthWeekIndex(for: date(2026, 8, 15), monthStart: monthStart, calendar: calendar), 2)
        XCTAssertEqual(RecapMath.monthWeekIndex(for: date(2026, 8, 31), monthStart: monthStart, calendar: calendar), 4)
    }

    /// August 2026 starts on a Saturday. The blocks must still run 1–7, 8–14 and
    /// so on regardless of which weekday the month opens on — that is what lets
    /// the bars and the "this week" highlight share one definition instead of
    /// each deriving their own.
    func testMonthWeekIndexIgnoresWhichWeekdayTheMonthStartsOn() {
        let monthStart = date(2026, 8, 1) // Saturday
        for day in 1...7 {
            XCTAssertEqual(
                RecapMath.monthWeekIndex(for: date(2026, 8, day), monthStart: monthStart, calendar: calendar),
                0,
                "day \(day) belongs to the first block"
            )
        }
        for day in 8...14 {
            XCTAssertEqual(
                RecapMath.monthWeekIndex(for: date(2026, 8, day), monthStart: monthStart, calendar: calendar),
                1,
                "day \(day) belongs to the second block"
            )
        }
    }

    /// The same must hold for a month that opens on the first weekday.
    func testMonthWeekIndexIsIdenticalForAMonthStartingOnAMonday() {
        let monthStart = date(2026, 6, 1) // Monday
        XCTAssertEqual(RecapMath.monthWeekIndex(for: date(2026, 6, 7), monthStart: monthStart, calendar: calendar), 0)
        XCTAssertEqual(RecapMath.monthWeekIndex(for: date(2026, 6, 8), monthStart: monthStart, calendar: calendar), 1)
    }

    func testMonthWeekIndexIgnoresTimeOfDay() {
        let monthStart = date(2026, 8, 1)
        XCTAssertEqual(
            RecapMath.monthWeekIndex(for: date(2026, 8, 8, hour: 0), monthStart: monthStart, calendar: calendar),
            RecapMath.monthWeekIndex(for: date(2026, 8, 8, hour: 23), monthStart: monthStart, calendar: calendar)
        )
    }

    func testMonthWeekIndexIsNegativeBeforeTheMonthStarts() {
        // Callers bounds-check the result; it must not round up into block 0.
        let monthStart = date(2026, 8, 1)
        XCTAssertLessThan(
            RecapMath.monthWeekIndex(for: date(2026, 7, 31, hour: 23), monthStart: monthStart, calendar: calendar),
            0
        )
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

    func testFutureEntryLaterInCurrentWeekIsExcluded() {
        let futureFriday = date(2026, 8, 21)
        let split = RecapMath.splitWeeks(
            [makeEntry(10, on: now), makeEntry(25, on: futureFriday)],
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(split.thisWeek.map(\.amount), [10])
    }

    // MARK: - dailyTotals (index 0 = calendar's first weekday)

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

    /// The chart and the total have to agree: `splitWeeks` drops future-dated
    /// entries, so a bar must not appear for one either.
    func testDailyTotalsExcludeFutureDaysInCurrentWeek() {
        let futureFriday = date(2026, 8, 21) // still inside the current week
        let totals = RecapMath.dailyTotals(
            [makeEntry(10, on: now), makeEntry(25, on: futureFriday)],
            calendar: calendar,
            now: now
        )
        XCTAssertEqual(totals[2], 10) // Wednesday, today
        XCTAssertEqual(totals[4], 0)  // Friday, not yet spent
        XCTAssertEqual(totals.reduce(0) { $0 + $1 }, 10)
    }

    /// Later the same day still counts — the cut-off is "after now", not
    /// "after today", so an entry timestamped this evening isn't dropped from
    /// today's bar the moment the clock passes it.
    func testDailyTotalsKeepEarlierEntriesOnToday() {
        let thisMorning = date(2026, 8, 19, hour: 9)
        let totals = RecapMath.dailyTotals(
            [makeEntry(6, on: thisMorning), makeEntry(4, on: now)],
            calendar: calendar,
            now: now
        )
        XCTAssertEqual(totals[2], 10)
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

    // MARK: - Sunday-first locales (en_IN / en_US)

    func testSundayFirstDailyTotalsAlignWithWeekStart() {
        let sundayNow = date(2026, 8, 26) // Wednesday inside the Sun 8/23 – Sat 8/29 week
        let entries = [
            makeEntry(45, on: date(2026, 8, 23)), // Sunday → index 0
            makeEntry(10, on: date(2026, 8, 24)), // Monday → index 1
            makeEntry(20, on: sundayNow),         // Wednesday → index 3
            makeEntry(99, on: date(2026, 8, 22)), // Saturday before the week — excluded
        ]
        let totals = RecapMath.dailyTotals(entries, calendar: sundayFirstCalendar, now: sundayNow)
        XCTAssertEqual(totals[0], 45) // Sunday money sits under the first bar
        XCTAssertEqual(totals[1], 10)
        XCTAssertEqual(totals[3], 20)
        XCTAssertEqual(totals.reduce(0) { $0 + $1 }, Decimal(string: "75.0") ?? 75)
    }

    func testSundayFirstTodayIndexMatchesBucketIndices() {
        XCTAssertEqual(RecapMath.todayIndex(calendar: sundayFirstCalendar, now: date(2026, 8, 23)), 0) // Sun
        XCTAssertEqual(RecapMath.todayIndex(calendar: sundayFirstCalendar, now: date(2026, 8, 24)), 1) // Mon
        XCTAssertEqual(RecapMath.todayIndex(calendar: sundayFirstCalendar, now: date(2026, 8, 26)), 3) // Wed
        XCTAssertEqual(RecapMath.todayIndex(calendar: sundayFirstCalendar, now: date(2026, 8, 29)), 6) // Sat
    }

    // MARK: - weekdayLabels

    func testWeekdayLabelsRotateWithFirstWeekday() {
        XCTAssertEqual(RecapMath.weekdayLabels(calendar: calendar), ["M", "T", "W", "T", "F", "S", "S"])
        XCTAssertEqual(RecapMath.weekdayLabels(calendar: sundayFirstCalendar), ["S", "M", "T", "W", "T", "F", "S"])
    }

    // MARK: - intentBreakdown

    private func marked(_ amount: Decimal, _ intent: SpendIntent?, category: String = "chai") -> Entry {
        Entry(amount: amount, category: category, date: now, intent: intent)
    }

    func testBreakdownSeparatesMarkedFromUnmarkedSpend() {
        let breakdown = RecapMath.intentBreakdown([
            marked(30, .impulse),
            marked(10, .impulse),
            marked(60, .planned),
            marked(400, nil),
        ])
        XCTAssertEqual(breakdown.impulse, 40)
        XCTAssertEqual(breakdown.planned, 60)
        XCTAssertEqual(breakdown.unmarked, 400)
        XCTAssertEqual(breakdown.marked, 100)
        XCTAssertEqual(breakdown.total, 500)
        XCTAssertEqual(breakdown.markedCount, 3)
        XCTAssertEqual(breakdown.entryCount, 4)
    }

    /// The share is taken over marked spend only. The 400 of unmarked spend above
    /// must not dilute it — folding it in either direction would invent an answer.
    func testImpulseShareIgnoresUnmarkedSpend() {
        let breakdown = RecapMath.intentBreakdown([
            marked(40, .impulse),
            marked(60, .planned),
            marked(400, nil),
        ])
        XCTAssertEqual(breakdown.impulseShare, Decimal(string: "0.4"))
        XCTAssertEqual(breakdown.coverage, Decimal(string: "0.2"))
    }

    /// The case that made this whole change necessary: a user who never touches
    /// the control must be told nothing, not told that all of their spending was
    /// impulsive — and not shown a fake 0% either.
    func testAllUnmarkedPeriodHasNoShareAndZeroCoverage() {
        let breakdown = RecapMath.intentBreakdown([
            marked(10, nil),
            marked(20, nil),
        ])
        XCTAssertNil(breakdown.impulseShare)
        XCTAssertEqual(breakdown.coverage, 0)
        XCTAssertEqual(breakdown.markedCount, 0)
        XCTAssertEqual(breakdown.entryCount, 2)
        XCTAssertEqual(breakdown.unmarked, 30)
    }

    func testEmptyPeriodHasNoShareAndNoCoverage() {
        let breakdown = RecapMath.intentBreakdown([])
        XCTAssertNil(breakdown.impulseShare, "no entries means no share to report")
        XCTAssertNil(breakdown.coverage, "coverage of an empty period is meaningless, not 0%")
        XCTAssertEqual(breakdown.total, 0)
        XCTAssertEqual(breakdown.entryCount, 0)
    }

    func testFullyMarkedPeriodReportsCompleteCoverage() {
        let breakdown = RecapMath.intentBreakdown([
            marked(25, .impulse),
            marked(75, .planned),
        ])
        XCTAssertEqual(breakdown.coverage, 1)
        XCTAssertEqual(breakdown.impulseShare, Decimal(string: "0.25"))
    }

    func testAllMarkedSpendOnOneSideGivesAWholeShare() {
        XCTAssertEqual(RecapMath.intentBreakdown([marked(50, .impulse)]).impulseShare, 1)
        XCTAssertEqual(RecapMath.intentBreakdown([marked(50, .planned)]).impulseShare, 0)
    }

    // MARK: - intentBreakdown(byCategory:)

    func testBreakdownByCategoryKeepsEachCategorysMarksSeparate() {
        let breakdowns = RecapMath.intentBreakdown(byCategory: [
            marked(30, .impulse, category: "chai"),
            marked(10, .planned, category: "chai"),
            marked(50, .planned, category: "bills"),
            marked(20, nil, category: "food"),
        ])
        XCTAssertEqual(breakdowns["chai"]?.impulseShare, Decimal(string: "0.75"))
        XCTAssertEqual(breakdowns["bills"]?.impulseShare, 0)
        XCTAssertNil(breakdowns["food"]?.impulseShare, "an unmarked category answers nothing")
        XCTAssertEqual(breakdowns["food"]?.entryCount, 1)
        XCTAssertNil(breakdowns["transport"], "categories with no spend do not appear")
    }

    func testBreakdownByCategoryCountsPartialMarking() {
        let breakdowns = RecapMath.intentBreakdown(byCategory: [
            marked(30, .impulse, category: "chai"),
            marked(70, nil, category: "chai"),
        ])
        XCTAssertEqual(breakdowns["chai"]?.markedCount, 1)
        XCTAssertEqual(breakdowns["chai"]?.entryCount, 2)
        XCTAssertEqual(breakdowns["chai"]?.coverage, Decimal(string: "0.3"))
    }

    // MARK: - impulseShareDelta

    func testDeltaIsMeasuredInShareDifference() {
        let current = RecapMath.intentBreakdown([marked(50, .impulse), marked(50, .planned)])
        let previous = RecapMath.intentBreakdown([marked(20, .impulse), marked(80, .planned)])
        // 50% now against 20% before — thirty points, not "150% more impulsive".
        XCTAssertEqual(RecapMath.impulseShareDelta(current: current, previous: previous), Decimal(string: "0.3"))
    }

    func testDeltaIsNegativeWhenImpulseShareFalls() {
        let current = RecapMath.intentBreakdown([marked(20, .impulse), marked(80, .planned)])
        let previous = RecapMath.intentBreakdown([marked(50, .impulse), marked(50, .planned)])
        XCTAssertEqual(RecapMath.impulseShareDelta(current: current, previous: previous), Decimal(string: "-0.3"))
    }

    func testDeltaIsNilWhenEitherPeriodHasNothingMarked() {
        let answered = RecapMath.intentBreakdown([marked(50, .impulse), marked(50, .planned)])
        let unanswered = RecapMath.intentBreakdown([marked(100, nil)])
        let empty = RecapMath.intentBreakdown([])
        XCTAssertNil(RecapMath.impulseShareDelta(current: answered, previous: unanswered))
        XCTAssertNil(RecapMath.impulseShareDelta(current: unanswered, previous: answered))
        XCTAssertNil(RecapMath.impulseShareDelta(current: answered, previous: empty))
    }

    func testDeltaIsZeroWhenTheShareIsUnchanged() {
        let current = RecapMath.intentBreakdown([marked(30, .impulse), marked(30, .planned)])
        let previous = RecapMath.intentBreakdown([marked(90, .impulse), marked(90, .planned)])
        XCTAssertEqual(RecapMath.impulseShareDelta(current: current, previous: previous), 0)
    }

    /// The recap feeds `splitWeeks` straight into the breakdown, so the previous
    /// period's comparison is only honest if the split itself is respected.
    func testBreakdownOverSplitWeeksComparesLikeWithLike() {
        let thisWeek = [
            Entry(amount: 60, category: "chai", date: date(2026, 8, 17), intent: .impulse),
            Entry(amount: 40, category: "chai", date: now, intent: .planned),
        ]
        let lastWeek = [
            Entry(amount: 10, category: "chai", date: date(2026, 8, 14), intent: .impulse),
            Entry(amount: 90, category: "chai", date: date(2026, 8, 13), intent: .planned),
        ]
        let split = RecapMath.splitWeeks(thisWeek + lastWeek, calendar: calendar, now: now)
        let current = RecapMath.intentBreakdown(split.thisWeek)
        let previous = RecapMath.intentBreakdown(split.lastWeek)
        XCTAssertEqual(current.impulseShare, Decimal(string: "0.6"))
        XCTAssertEqual(previous.impulseShare, Decimal(string: "0.1"))
        XCTAssertEqual(RecapMath.impulseShareDelta(current: current, previous: previous), Decimal(string: "0.5"))
    }
}
