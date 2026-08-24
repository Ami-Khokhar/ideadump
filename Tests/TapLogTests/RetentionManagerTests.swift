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

    private func seedPastWeek(
        mask: [Bool],
        streak: Int,
        resolved: Bool,
        freezes: Int = 0,
        frozen: Bool = false,
        weeklyTarget: Int = 5
    ) {
        defaults.set(Date.distantPast, forKey: "retention.weekStartDate")
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
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        let daysSinceMonday = (weekday + 5) % 7
        let monday = cal.startOfDay(for: cal.date(byAdding: .day, value: -daysSinceMonday, to: now)!)
        defaults.set(monday, forKey: "retention.weekStartDate")
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
}
