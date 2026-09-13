import XCTest
import SwiftData
@testable import TapLog

/// Verifies every capture front door produces identical product state:
/// category learning, log totals, and streaks — the parity contract between
/// the home screen, capture form, Siri/Shortcuts, and widget quick-log.
@MainActor
final class CaptureBookkeepingTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var categories: [SpendCategory] = []
    private let suiteName = "test.CaptureBookkeeping"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
        // Mark the isolated suite as already migrated so apply()'s one-time
        // legacy-state import can't pull this machine's real counters into tests.
        defaults.set(true, forKey: "retention.legacyMigrated")

        container = try! ModelContainer(
            for: Entry.self, SpendCategory.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
        let chai = SpendCategory(key: "chai", name: "Chai", emoji: "☕️")
        context.insert(chai)
        try? context.save()
        categories = [chai]
    }

    // MARK: - Archiving takes an entry out of the counted set

    /// Archiving hides an entry from every count in the app, so the counters it
    /// bumped when it was logged have to come back down — otherwise the recap
    /// keeps quoting a total the History no longer shows.
    func testArchivingRevertsWhatLoggingCounted() {
        let entry = Entry(amount: 45, category: "chai")
        context.insert(entry)
        try? context.save()
        CaptureBookkeeping.apply(
            modelContext: context, categories: categories,
            categoryKey: "chai", entryDate: entry.date, defaults: defaults
        )
        XCTAssertEqual(categories[0].logCount, 1)
        XCTAssertEqual(defaults.integer(forKey: "logsLogged"), 1)

        entry.isArchived = true
        try? context.save()
        CaptureBookkeeping.revert(
            modelContext: context, categories: categories,
            categoryKey: "chai", entryDate: entry.date, defaults: defaults
        )

        XCTAssertEqual(categories[0].logCount, 0)
        XCTAssertEqual(defaults.integer(forKey: "logsLogged"), 0)
    }

    /// Unarchiving is the mirror: back in the set, counted again.
    func testUnarchivingCountsItAgain() {
        let entry = Entry(amount: 45, category: "chai", isArchived: true)
        context.insert(entry)
        try? context.save()

        entry.isArchived = false
        try? context.save()
        CaptureBookkeeping.apply(
            modelContext: context, categories: categories,
            categoryKey: "chai", entryDate: entry.date, defaults: defaults
        )

        XCTAssertEqual(categories[0].logCount, 1)
        XCTAssertEqual(defaults.integer(forKey: "logsLogged"), 1)
    }

    /// An archived row deleted from the Archived list must not pay twice: its
    /// counters already came down when it was archived.
    func testArchiveThenDeleteTakesTheCountDownOnlyOnce() {
        let entry = Entry(amount: 45, category: "chai")
        context.insert(entry)
        try? context.save()
        CaptureBookkeeping.apply(
            modelContext: context, categories: categories,
            categoryKey: "chai", entryDate: entry.date, defaults: defaults
        )

        // Archive: one revert.
        let archivedDate = entry.date
        entry.isArchived = true
        try? context.save()
        CaptureBookkeeping.revert(
            modelContext: context, categories: categories,
            categoryKey: "chai", entryDate: archivedDate, defaults: defaults
        )

        // Delete: EntryListView skips the second revert for an archived row.
        context.delete(entry)
        try? context.save()

        XCTAssertEqual(categories[0].logCount, 0, "must not go negative or double-count")
        XCTAssertEqual(defaults.integer(forKey: "logsLogged"), 0)
    }

    /// The date matters: an entry rejoining the count lights its *own* day, and
    /// a day outside this week lights nothing at all.
    func testReapplyingAnOldEntryDoesNotLightToday() {
        let calendar = Calendar.current
        let retention = RetentionManager(defaults: defaults, calendar: calendar)
        let lastMonth = calendar.date(byAdding: .day, value: -35, to: Date())!

        retention.recordLogDay(on: lastMonth)

        XCTAssertEqual(retention.daysLoggedThisWeek, 0,
                       "a log from five weeks ago must not count toward this week")
        XCTAssertEqual(retention.totalLogs, 1, "but it is still a log that happened")
    }

    override func tearDown() {
        container.deleteAllData()
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// Simulates one completed log from any front door.
    private func logOne(categoryKey: String = "chai") {
        let entry = Entry(amount: 10, category: categoryKey)
        context.insert(entry)
        try? context.save()
        CaptureBookkeeping.apply(
            modelContext: context,
            categories: (try? context.fetch(FetchDescriptor<SpendCategory>())) ?? [],
            categoryKey: categoryKey,
            defaults: defaults
        )
    }

    private func currentCategories() -> [SpendCategory] {
        (try? context.fetch(FetchDescriptor<SpendCategory>())) ?? []
    }

    // MARK: - Undo (revert)

    func testRevertRestoresCountersWhenDayEmpties() {
        logOne()
        // An undo deletes the entry first, then reverts bookkeeping.
        for entry in try! context.fetch(FetchDescriptor<Entry>()) {
            context.delete(entry)
        }
        try? context.save()

        CaptureBookkeeping.revert(modelContext: context, categories: currentCategories(), categoryKey: "chai", defaults: defaults)

        XCTAssertEqual(currentCategories().first?.logCount, 0)
        XCTAssertEqual(defaults.integer(forKey: "logsLogged"), 0)
        let retention = RetentionManager(defaults: defaults)
        XCTAssertEqual(retention.totalLogs, 0)
        XCTAssertEqual(retention.daysLoggedThisWeek, 0, "undoing the day's only log clears its weekly bit")
    }

    func testRevertKeepsDayActiveWhileAnotherLogRemains() {
        logOne()
        logOne()
        let entries = try! context.fetch(FetchDescriptor<Entry>())
        context.delete(entries[0])
        try? context.save()

        CaptureBookkeeping.revert(modelContext: context, categories: currentCategories(), categoryKey: "chai", defaults: defaults)

        XCTAssertEqual(currentCategories().first?.logCount, 1)
        XCTAssertEqual(defaults.integer(forKey: "logsLogged"), 1)
        let retention = RetentionManager(defaults: defaults)
        XCTAssertEqual(retention.totalLogs, 1)
        XCTAssertEqual(retention.daysLoggedThisWeek, 1, "another log today keeps the day active")
    }

    // MARK: - Reset

    func testResetAllClearsTrackingButKeepsTargetPreference() {
        logOne()
        let retention = RetentionManager(defaults: defaults)
        retention.weeklyTarget = 6

        retention.resetAll()

        XCTAssertEqual(retention.totalLogs, 0)
        XCTAssertEqual(retention.currentStreak, 0)
        XCTAssertEqual(retention.longestStreak, 0)
        XCTAssertEqual(retention.streakFreezes, 0)
        XCTAssertEqual(retention.daysLoggedThisWeek, 0)
        XCTAssertEqual(retention.weeklyTarget, 6, "the target is a preference, not progress")
    }

    func testApplyCountsCategoryLearningTotalsAndStreak() {
        logOne()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SpendCategory>()), 1)
        let chai = try! context.fetch(FetchDescriptor<SpendCategory>()).first!
        XCTAssertEqual(chai.logCount, 1)

        XCTAssertEqual(defaults.integer(forKey: "logsLogged"), 1)

        let retention = RetentionManager(defaults: defaults)
        XCTAssertEqual(retention.totalLogs, 1)
        XCTAssertEqual(retention.daysLoggedThisWeek, 1)
    }

    func testTwoLogsSameDayCountOnceTowardWeeklyTargetButBothAsTotal() {
        logOne()
        logOne()

        XCTAssertEqual(defaults.integer(forKey: "logsLogged"), 2)
        let retention = RetentionManager(defaults: defaults)
        XCTAssertEqual(retention.totalLogs, 2)
        XCTAssertEqual(retention.daysLoggedThisWeek, 1, "two logs on one day are still one active day")
    }

    func testUnknownCategoryStillCountsTheLog() {
        logOne(categoryKey: "ghost")

        XCTAssertEqual(defaults.integer(forKey: "logsLogged"), 1)
        XCTAssertEqual(RetentionManager(defaults: defaults).totalLogs, 1)
    }

    func testFallbackCategoryWorksWhenNothingSeeded() {
        // Fresh store with no categories at all — first-ever log path.
        for category in try! context.fetch(FetchDescriptor<SpendCategory>()) {
            context.delete(category)
        }
        try? context.save()

        logOne(categoryKey: SpendCategory.fallbackKey)

        XCTAssertEqual(defaults.integer(forKey: "logsLogged"), 1)
    }

    func testTenLogsAwardAStreakFreeze() {
        for _ in 0..<10 { logOne() }
        XCTAssertEqual(RetentionManager(defaults: defaults).streakFreezes, 1)
    }

    // MARK: - Day-exact undo

    func testRevertClearsTheRecordedDayNotTodayAfterMidnight() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let yesterdayEntry = Entry(amount: 10, category: "chai", date: yesterday)
        context.insert(yesterdayEntry)
        context.insert(Entry(amount: 10, category: "chai"))
        try? context.save()
        for _ in 0..<2 {
            CaptureBookkeeping.apply(modelContext: context, categories: currentCategories(), categoryKey: "chai", defaults: defaults)
        }

        context.delete(yesterdayEntry)
        try? context.save()

        CaptureBookkeeping.revert(
            modelContext: context,
            categories: currentCategories(),
            categoryKey: "chai",
            entryDate: yesterday,
            defaults: defaults
        )

        XCTAssertEqual(currentCategories().first?.logCount, 1)
        XCTAssertEqual(defaults.integer(forKey: "logsLogged"), 1)
        let retention = RetentionManager(defaults: defaults)
        XCTAssertEqual(retention.totalLogs, 1)
        // Exactly one active day remains: today's. Yesterday's bit was cleared
        // if it belonged to this week, or left to the resolved prior week.
        XCTAssertEqual(retention.daysLoggedThisWeek, 1)
    }

    // MARK: - Clean-slate helper

    func testResetCategoryUsageZeroesAllCounters() {
        let chai = currentCategories().first!
        chai.logCount = 5
        try? context.save()

        CaptureBookkeeping.resetCategoryUsage(modelContext: context)

        XCTAssertEqual(currentCategories().first?.logCount, 0)
    }

    // MARK: - Undoing a log

    /// What the widget's undo toast actually runs. The toast lives for five
    /// seconds, so this is the only place the behaviour can be pinned.
    func testUndoLogRemovesTheEntryAndItsBookkeeping() throws {
        logOne()
        let chai = try XCTUnwrap(categories.first)
        XCTAssertEqual(chai.logCount, 1)
        XCTAssertEqual(defaults.integer(forKey: "logsLogged"), 1)
        let entry = try XCTUnwrap(context.fetch(FetchDescriptor<Entry>()).first)

        let undone = CaptureBookkeeping.undoLog(
            entry: entry,
            modelContext: context,
            categories: categories,
            defaults: defaults
        )

        XCTAssertTrue(undone)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Entry>()).isEmpty, "the row goes with the counters")
        XCTAssertEqual(chai.logCount, 0, "category learning must not keep counting a log that was taken back")
        XCTAssertEqual(defaults.integer(forKey: "logsLogged"), 0)
    }

    /// Two logs on one day, one undone: the day is still an active day, so the
    /// streak must survive.
    func testUndoLogLeavesTheDayAliveWhenAnotherLogRemains() throws {
        logOne()
        logOne()
        let entries = try context.fetch(FetchDescriptor<Entry>())
        XCTAssertEqual(entries.count, 2)
        let chai = try XCTUnwrap(categories.first)

        CaptureBookkeeping.undoLog(
            entry: entries[0],
            modelContext: context,
            categories: categories,
            defaults: defaults
        )

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Entry>()), 1)
        XCTAssertEqual(chai.logCount, 1, "only the undone log is discounted")
        XCTAssertEqual(defaults.integer(forKey: "logsLogged"), 1)
    }
}
