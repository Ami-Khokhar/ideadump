import XCTest
@testable import TapLog

/// Week-boundary behavior of the streak tracker.
///
/// Freeze semantics: a frozen week preserves the streak (no increment, no reset).
/// Only a target-met week increments. A missed+unfrozen week resets.
final class RetentionManagerTests: XCTestCase {
    private let suiteName = "test.RetentionManager"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// Both seeds write already-aligned state: they exercise rollover and freeze
    /// semantics, not the one-time Monday→locale realignment, which has its own
    /// tests below.
    private func seedPastWeek(
        mask: [Bool],
        streak: Int,
        resolved: Bool,
        freezes: Int = 0,
        frozen: Bool = false,
        weeklyTarget: Int = 5
    ) {
        defaults.set(Date.distantPast, forKey: "retention.weekStartDate")
        defaults.set(true, forKey: "retention.weekAlignmentMigrated")
        defaults.set(mask, forKey: "retention.weeklyMask")
        defaults.set(streak, forKey: "retention.currentStreak")
        defaults.set(resolved, forKey: "retention.weekResolved")
        defaults.set(frozen, forKey: "retention.weekFrozen")
        defaults.set(freezes, forKey: "retention.streakFreezes")
        defaults.set(weeklyTarget, forKey: "retention.weeklyTarget")
    }

    private func seedCurrentWeek(
        mask: [Bool],
        streak: Int = 0,
        resolved: Bool = false,
        frozen: Bool = false,
        freezes: Int = 0,
        weeklyTarget: Int = 5
    ) {
        defaults.set(RetentionManager.weekStart(containing: Date()), forKey: "retention.weekStartDate")
        defaults.set(true, forKey: "retention.weekAlignmentMigrated")
        defaults.set(mask, forKey: "retention.weeklyMask")
        defaults.set(streak, forKey: "retention.currentStreak")
        defaults.set(resolved, forKey: "retention.weekResolved")
        defaults.set(frozen, forKey: "retention.weekFrozen")
        defaults.set(freezes, forKey: "retention.streakFreezes")
        defaults.set(weeklyTarget, forKey: "retention.weeklyTarget")
    }

    // MARK: - Rollover: target met → increment

    func testRolloverExtendsStreakExactlyOnceForCompleteWeek() {
        seedPastWeek(
            mask: Array(repeating: true, count: 7),
            streak: 2,
            resolved: false
        )
        let retention = RetentionManager(defaults: defaults)

        XCTAssertEqual(retention.daysLoggedThisWeek, 0, "the new week starts empty")
        XCTAssertEqual(retention.currentStreak, 3, "a complete prior week extends the streak exactly once")
        XCTAssertFalse(defaults.bool(forKey: "retention.weekResolved"), "the new week starts unresolved")
    }

    // MARK: - Rollover: target missed + not frozen → break

    func testRolloverBreaksStreakForIncompleteWeek() {
        seedPastWeek(
            mask: [true, false, false, false, false, false, false],
            streak: 4,
            resolved: false
        )
        let retention = RetentionManager(defaults: defaults)

        _ = retention.daysLoggedThisWeek

        XCTAssertEqual(retention.currentStreak, 0)
    }

    // MARK: - Rollover: frozen + target missed → preserve (no increment)

    /// Regression: a frozen week starting with streak 5 should roll over with
    /// streak 5, not 6.
    func testFrozenWeekPreservesStreakAcrossRollover() {
        seedPastWeek(
            mask: [true, false, false, false, false, false, false], // 1 day < target 5
            streak: 5,
            resolved: false,
            frozen: true
        )
        let retention = RetentionManager(defaults: defaults)

        _ = retention.daysLoggedThisWeek

        XCTAssertEqual(retention.currentStreak, 5,
                       "frozen week should preserve the streak (no increment)")
        XCTAssertFalse(defaults.bool(forKey: "retention.weekFrozen"),
                       "new week starts unfrozen")
    }

    // MARK: - Rollover: resolved → preserved (skipped, not incremented again)

    func testRolloverKeepsStreakWhenAFreezeAlreadySavedTheWeek() {
        seedPastWeek(
            mask: Array(repeating: false, count: 7),
            streak: 5,
            resolved: true
        )
        let retention = RetentionManager(defaults: defaults)

        _ = retention.daysLoggedThisWeek

        XCTAssertEqual(retention.currentStreak, 5)
    }

    func testResolvedAndFrozenBothPreserveStreak() {
        seedPastWeek(
            mask: Array(repeating: true, count: 7),
            streak: 3,
            resolved: true,
            frozen: true
        )
        let retention = RetentionManager(defaults: defaults)

        _ = retention.daysLoggedThisWeek

        // Week was already resolved → refreshWeekIfNeeded skips the block → streak unchanged.
        XCTAssertEqual(retention.currentStreak, 3,
                       "resolved week preserves streak; frozen flag is redundant")
        XCTAssertFalse(defaults.bool(forKey: "retention.weekFrozen"),
                       "new week starts unfrozen")
    }

    func testUnresolvedUnfrozenWeekBreaksStreak() {
        seedPastWeek(
            mask: [true, false, false, false, false, false, false],
            streak: 3,
            resolved: false,
            frozen: false
        )
        let retention = RetentionManager(defaults: defaults)

        _ = retention.daysLoggedThisWeek

        XCTAssertEqual(retention.currentStreak, 0,
                       "unresolved + unfrozen week breaks the streak")
    }

    // MARK: - New week earns streak

    func testNewWeekCanEarnStreakAfterIncompletePreviousWeek() {
        seedPastWeek(
            mask: [true, false, false, false, false, false, false],
            streak: 4,
            resolved: false
        )
        let retention = RetentionManager(defaults: defaults)
        retention.weeklyTarget = 3

        _ = retention.daysLoggedThisWeek
        XCTAssertFalse(defaults.bool(forKey: "retention.weekResolved"), "the new week starts unresolved")

        defaults.set([true, true, true, false, false, false, false], forKey: "retention.weeklyMask")
        retention.recordLogDay()

        XCTAssertEqual(retention.currentStreak, 1, "the new week can earn its own streak")
        XCTAssertTrue(defaults.bool(forKey: "retention.weekResolved"))
    }

    // MARK: - Freeze semantics (current week, no rollover)

    func testFreezeFollowedByTargetCompletionExtendsStreak() {
        seedCurrentWeek(
            mask: [false, false, false, false, false, false, false],
            streak: 0,
            freezes: 2,
            weeklyTarget: 3
        )
        let retention = RetentionManager(defaults: defaults)

        XCTAssertTrue(retention.useStreakFreeze(), "freeze should be available")
        XCTAssertEqual(retention.streakFreezes, 1, "one freeze consumed")

        XCTAssertFalse(defaults.bool(forKey: "retention.weekResolved"),
                       "freeze should not set weekResolved")
        XCTAssertTrue(defaults.bool(forKey: "retention.weekFrozen"),
                      "freeze should set weekFrozen")

        defaults.set([true, true, true, false, false, false, false], forKey: "retention.weeklyMask")
        retention.recordLogDay()

        XCTAssertEqual(retention.currentStreak, 1,
                       "target completion after freeze must extend the streak")
        XCTAssertTrue(defaults.bool(forKey: "retention.weekResolved"))
    }

    func testFreezeCannotBeUsedTwiceInSameWeek() {
        seedCurrentWeek(
            mask: [true, false, false, false, false, false, false],
            streak: 0,
            freezes: 3,
            weeklyTarget: 5
        )
        let retention = RetentionManager(defaults: defaults)

        XCTAssertTrue(retention.useStreakFreeze(), "first freeze should succeed")
        XCTAssertFalse(retention.useStreakFreeze(), "second freeze should fail in same week")
        XCTAssertEqual(retention.streakFreezes, 2)
    }

    func testFreezeCannotBeUsedWhenTargetAlreadyMet() {
        seedCurrentWeek(
            mask: [true, true, true, false, false, false, false],
            streak: 0,
            freezes: 2,
            weeklyTarget: 3
        )
        let retention = RetentionManager(defaults: defaults)

        XCTAssertTrue(retention.targetMet)
        XCTAssertFalse(retention.useStreakFreeze(),
                        "should not allow freeze when target is already met")
        XCTAssertEqual(retention.streakFreezes, 2, "freeze not consumed")
    }

    // MARK: - Freeze button availability

    /// The recap's "Use a freeze" button asked a different question than
    /// `useStreakFreeze` answered, so after one use it stayed on screen and did
    /// nothing for the rest of the week. One property now answers both.
    func testFreezeAvailabilityGoesFalseOnceSpent() {
        seedCurrentWeek(
            mask: [true, false, false, false, false, false, false],
            streak: 0,
            freezes: 3,
            weeklyTarget: 5
        )
        let retention = RetentionManager(defaults: defaults)

        XCTAssertTrue(retention.canUseStreakFreeze)
        XCTAssertTrue(retention.useStreakFreeze())
        XCTAssertFalse(retention.canUseStreakFreeze,
                       "the button must not offer a freeze this week again")
        XCTAssertFalse(retention.useStreakFreeze())
    }

    /// Every case where the button is hidden must be a case where the action
    /// would refuse, and the reverse.
    func testFreezeAvailabilityAgreesWithTheAction() {
        for (mask, freezes, target) in [
            ([true, false, false, false, false, false, false], 0, 5),
            ([true, true, true, false, false, false, false], 2, 3),
            ([true, false, false, false, false, false, false], 2, 5),
            ([false, false, false, false, false, false, false], 3, 7)
        ] as [([Bool], Int, Int)] {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
            seedCurrentWeek(mask: mask, streak: 0, freezes: freezes, weeklyTarget: target)
            let retention = RetentionManager(defaults: defaults)

            let offered = retention.canUseStreakFreeze
            XCTAssertEqual(offered, retention.useStreakFreeze(),
                           "mask \(mask), freezes \(freezes), target \(target)")
        }
    }

    // MARK: - Legacy migration

    func testLegacyStateMigratesOnceAndTargetValuesWin() {
        let legacySuite = "test.RetentionManager.legacy"
        UserDefaults.standard.removePersistentDomain(forName: legacySuite)
        defer { UserDefaults.standard.removePersistentDomain(forName: legacySuite) }
        let legacy = UserDefaults(suiteName: legacySuite)!
        legacy.set(3, forKey: "retention.currentStreak")
        legacy.set(7, forKey: "retention.weeklyTarget")
        legacy.set(42, forKey: "logsLogged")

        defaults.set(1, forKey: "retention.currentStreak")

        RetentionManager.migrateLegacyStateIfNeeded(target: defaults, legacy: legacy)

        XCTAssertEqual(defaults.integer(forKey: "retention.currentStreak"), 1, "newer values win over legacy ones")
        XCTAssertEqual(defaults.integer(forKey: "retention.weeklyTarget"), 7)
        XCTAssertEqual(defaults.integer(forKey: "logsLogged"), 42)
        XCTAssertTrue(defaults.bool(forKey: "retention.legacyMigrated"))

        legacy.set(99, forKey: "retention.weeklyTarget")
        RetentionManager.migrateLegacyStateIfNeeded(target: defaults, legacy: legacy)
        XCTAssertEqual(defaults.integer(forKey: "retention.weeklyTarget"), 7)
    }

    // MARK: - Locale week alignment

    /// Monday-first (much of Europe) and Sunday-first (en_US, en_IN) calendars,
    /// pinned the way RecapMathTests pins them so the two files are talking about
    /// the same weeks.
    private var mondayFirst: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    private var sundayFirst: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    /// 2026-08-16 is a Sunday, 2026-08-17 the Monday after it, 2026-08-19 the
    /// Wednesday after that.
    private func day(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testWeekStartFollowsFirstWeekday() {
        let wednesday = day(2026, 8, 19, calendar: mondayFirst)

        XCTAssertEqual(
            RetentionManager.weekStart(containing: wednesday, calendar: mondayFirst),
            mondayFirst.startOfDay(for: day(2026, 8, 17, calendar: mondayFirst)),
            "a Monday-first calendar starts the week on Monday the 17th"
        )
        XCTAssertEqual(
            RetentionManager.weekStart(containing: wednesday, calendar: sundayFirst),
            sundayFirst.startOfDay(for: day(2026, 8, 16, calendar: sundayFirst)),
            "a Sunday-first calendar starts the same week on Sunday the 16th"
        )
    }

    /// The bug this milestone exists for: on en_IN the recap put a Sunday log in
    /// the week that Sunday opens, while the hardcoded-Monday streak put it in
    /// the week that was closing. One log, two different weeks, and a streak that
    /// broke on a day the user had actually logged.
    func testSundayLogLandsInTheSameWeekForStreakAndRecap() {
        let sunday = day(2026, 8, 16, calendar: sundayFirst)
        let wednesday = day(2026, 8, 19, calendar: sundayFirst)

        let sundayEntry = Entry(amount: 10, category: "chai", date: sunday)
        let split = RecapMath.splitWeeks([sundayEntry], calendar: sundayFirst, now: wednesday)
        XCTAssertEqual(split.thisWeek.count, 1, "the recap counts Sunday as the start of this week")

        XCTAssertEqual(
            RetentionManager.weekStart(containing: sunday, calendar: sundayFirst),
            RetentionManager.weekStart(containing: wednesday, calendar: sundayFirst),
            "so the streak must put that Sunday in this week too"
        )
        XCTAssertEqual(
            RetentionManager.maskIndex(
                for: sunday,
                weekStart: RetentionManager.weekStart(containing: wednesday, calendar: sundayFirst),
                calendar: sundayFirst
            ),
            0,
            "and mark it as the week's first day"
        )
    }

    func testMaskIndexRejectsDaysOutsideTheWeek() {
        let start = RetentionManager.weekStart(
            containing: day(2026, 8, 19, calendar: mondayFirst),
            calendar: mondayFirst
        )

        XCTAssertEqual(
            RetentionManager.maskIndex(for: day(2026, 8, 23, calendar: mondayFirst), weekStart: start, calendar: mondayFirst),
            6,
            "Sunday the 23rd is the last day of a Monday-first week"
        )
        XCTAssertNil(
            RetentionManager.maskIndex(for: day(2026, 8, 24, calendar: mondayFirst), weekStart: start, calendar: mondayFirst),
            "the following Monday belongs to the next week, not index 0 of this one"
        )
        XCTAssertNil(
            RetentionManager.maskIndex(for: day(2026, 8, 16, calendar: mondayFirst), weekStart: start, calendar: mondayFirst),
            "the preceding Sunday is before the window"
        )
    }

    // MARK: - One-time realignment of stored state

    /// Stored state as the removed `currentMonday()` would have written it: the
    /// start is always a Monday and the mask is indexed from it.
    ///
    /// The Monday used is the one inside *this* locale week, so the realignment
    /// lands on the current window and the week-rollover path stays out of the
    /// way — these tests are about the shift, not about crossing a boundary.
    private func seedLegacyMondayWeek(mask: [Bool], calendar: Calendar) -> Date {
        let weekStart = RetentionManager.weekStart(containing: Date(), calendar: calendar)
        let offset = (2 - calendar.firstWeekday + 7) % 7 // days from week start to Monday
        let monday = calendar.date(byAdding: .day, value: offset, to: weekStart)!
        defaults.set(monday, forKey: "retention.weekStartDate")
        defaults.set(mask, forKey: "retention.weeklyMask")
        defaults.removeObject(forKey: "retention.weekAlignmentMigrated")
        return weekStart
    }

    func testRealignmentShiftsTheMaskOntoASundayFirstWeek() {
        // Logged the Monday and Tuesday of a week the old code recorded as
        // starting on that Monday.
        let expectedStart = seedLegacyMondayWeek(
            mask: [true, true, false, false, false, false, false],
            calendar: sundayFirst
        )
        let retention = RetentionManager(defaults: defaults, calendar: sundayFirst)

        _ = retention.daysLoggedThisWeek

        XCTAssertEqual(
            defaults.object(forKey: "retention.weekStartDate") as? Date,
            expectedStart,
            "the window moves back to the Sunday that really opens that week"
        )
        XCTAssertEqual(
            defaults.array(forKey: "retention.weeklyMask") as? [Bool],
            [false, true, true, false, false, false, false],
            "and the logged days move with it — still Monday and Tuesday"
        )
    }

    func testRealignmentDropsADayThatFallsIntoTheNextWeek() {
        // Logged the Sunday that closed an old Monday-first week. Under a
        // Sunday-first calendar that day opens the *next* week, so it cannot be
        // represented in this window at all.
        _ = seedLegacyMondayWeek(
            mask: [false, false, false, false, false, false, true],
            calendar: sundayFirst
        )
        let retention = RetentionManager(defaults: defaults, calendar: sundayFirst)

        _ = retention.daysLoggedThisWeek

        XCTAssertEqual(
            defaults.array(forKey: "retention.weeklyMask") as? [Bool],
            Array(repeating: false, count: 7),
            "dropped, not wrapped to index 0 — wrapping would credit a day the user has not lived yet"
        )
    }

    func testRealignmentIsANoOpOnAMondayFirstCalendar() {
        let expectedStart = seedLegacyMondayWeek(
            mask: [true, false, true, false, false, false, false],
            calendar: mondayFirst
        )
        let retention = RetentionManager(defaults: defaults, calendar: mondayFirst)

        _ = retention.daysLoggedThisWeek

        XCTAssertEqual(defaults.object(forKey: "retention.weekStartDate") as? Date, expectedStart)
        XCTAssertEqual(
            defaults.array(forKey: "retention.weeklyMask") as? [Bool],
            [true, false, true, false, false, false, false],
            "a Monday-first user's stored week was already correct"
        )
    }

    func testRealignmentRunsOnlyOnce() {
        _ = seedLegacyMondayWeek(
            mask: [true, false, false, false, false, false, false],
            calendar: sundayFirst
        )
        _ = RetentionManager(defaults: defaults, calendar: sundayFirst).daysLoggedThisWeek

        // A second pass over already-aligned state would shift the mask again.
        _ = RetentionManager(defaults: defaults, calendar: sundayFirst).daysLoggedThisWeek

        XCTAssertEqual(
            defaults.array(forKey: "retention.weeklyMask") as? [Bool],
            [false, true, false, false, false, false, false],
            "the logged day stays on Monday instead of drifting a slot per launch"
        )
        XCTAssertTrue(defaults.bool(forKey: "retention.weekAlignmentMigrated"))
    }

    func testFreshInstallNeedsNoRealignment() {
        let retention = RetentionManager(defaults: defaults, calendar: sundayFirst)

        XCTAssertEqual(retention.daysLoggedThisWeek, 0)
        XCTAssertTrue(defaults.bool(forKey: "retention.weekAlignmentMigrated"),
                      "the flag is claimed even with nothing to move, so it never runs later against aligned state")
    }
}
