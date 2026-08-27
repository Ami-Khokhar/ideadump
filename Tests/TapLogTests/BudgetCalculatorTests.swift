import XCTest
import Foundation
@testable import TapLog

/// Deterministic coverage for the pure budget math. Uses a fixed UTC calendar
/// with a Monday-first week so weekly boundaries are unambiguous across
/// timezones and locales.
final class BudgetCalculatorTests: XCTestCase {

    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday — matches the app's Monday-first week
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// 2026-08-19 is a Wednesday at 12:00 UTC — middle of the week, middle of
    /// the month, so weekly and monthly intervals are both well-defined.
    private var now: Date { date(2026, 8, 19, hour: 12) }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func makeCategory(
        key: String = "chai",
        target: Decimal? = Decimal(string: "100"),
        period: BudgetPeriod? = .weekly
    ) -> SpendCategory {
        SpendCategory(
            key: key,
            name: key.capitalized,
            emoji: "☕️",
            budgetTarget: target,
            budgetPeriod: period
        )
    }

    private func entry(_ amount: Decimal, on date: Date, category: String = "chai",
                       isArchived: Bool = false, isPending: Bool = false) -> Entry {
        // Parameter order mirrors Entry.init: isArchived comes before isPending.
        Entry(
            amount: amount,
            category: category,
            date: date,
            isArchived: isArchived,
            isPending: isPending
        )
    }

    // MARK: - Interval derivation

    func testWeeklyIntervalBracketsAcrossMondayMidnight() {
        let category = makeCategory(period: .weekly)
        let (current, previous) = BudgetCalculator.intervals(
            for: category, calendar: calendar, referenceDate: now
        )
        // This week starts Mon 2026-08-17; previous week Mon 2026-08-10.
        XCTAssertEqual(current.start, date(2026, 8, 17, hour: 0))
        XCTAssertEqual(current.end, date(2026, 8, 24, hour: 0))
        XCTAssertEqual(previous.start, date(2026, 8, 10, hour: 0))
        XCTAssertEqual(previous.end, date(2026, 8, 17, hour: 0))

        // Boundary: Mon 00:00 belongs to current, Sun 23:59 belongs to previous.
        XCTAssertTrue(current.contains(date(2026, 8, 17, hour: 0)))
        XCTAssertTrue(current.contains(date(2026, 8, 23, hour: 23)))
        XCTAssertFalse(current.contains(date(2026, 8, 24, hour: 0)))
        XCTAssertTrue(previous.contains(date(2026, 8, 16, hour: 23)))
        XCTAssertFalse(previous.contains(date(2026, 8, 17, hour: 0)))
    }

    func testMonthlyIntervalBracketsAcrossFirstOfMonth() {
        let category = makeCategory(period: .monthly)
        let (current, previous) = BudgetCalculator.intervals(
            for: category, calendar: calendar, referenceDate: now
        )
        // August current; July previous.
        XCTAssertEqual(current.start, date(2026, 8, 1, hour: 0))
        XCTAssertEqual(current.end, date(2026, 9, 1, hour: 0))
        XCTAssertEqual(previous.start, date(2026, 7, 1, hour: 0))
        XCTAssertEqual(previous.end, date(2026, 8, 1, hour: 0))

        // Boundary: Aug 1 00:00 belongs to current; Jul 31 23:59 belongs to previous.
        XCTAssertTrue(current.contains(date(2026, 8, 1, hour: 0)))
        XCTAssertTrue(current.contains(date(2026, 8, 31, hour: 23)))
        XCTAssertFalse(current.contains(date(2026, 9, 1, hour: 0)))
        XCTAssertTrue(previous.contains(date(2026, 7, 31, hour: 23)))
        XCTAssertFalse(previous.contains(date(2026, 8, 1, hour: 0)))
    }

    // MARK: - Period-driven interval overload

    func testPeriodDrivenWeeklyOverloadReturnsSameBracketsAsCategory() {
        let category = makeCategory(period: .weekly)
        let categoryBrackets = BudgetCalculator.intervals(
            for: category, calendar: calendar, referenceDate: now
        )
        let periodBrackets = BudgetCalculator.intervals(
            for: .weekly, calendar: calendar, referenceDate: now
        )
        XCTAssertEqual(periodBrackets.current, categoryBrackets.current)
        XCTAssertEqual(periodBrackets.previous, categoryBrackets.previous)
    }

    func testPeriodDrivenMonthlyOverloadReturnsSameBracketsAsCategory() {
        let category = makeCategory(period: .monthly)
        let categoryBrackets = BudgetCalculator.intervals(
            for: category, calendar: calendar, referenceDate: now
        )
        let periodBrackets = BudgetCalculator.intervals(
            for: .monthly, calendar: calendar, referenceDate: now
        )
        XCTAssertEqual(periodBrackets.current, categoryBrackets.current)
        XCTAssertEqual(periodBrackets.previous, categoryBrackets.previous)
    }

    func testPeriodOverloadIgnoresSavedCategoryPeriod() {
        // A category saved with weekly period, but we ask for monthly brackets.
        // The overload must return month boundaries, not the persisted weekly ones.
        let category = makeCategory(period: .weekly)
        let monthlyBrackets = BudgetCalculator.intervals(
            for: .monthly, calendar: calendar, referenceDate: now
        )
        // Verify we got August, not the current week.
        XCTAssertEqual(monthlyBrackets.current.start, date(2026, 8, 1, hour: 0))
        XCTAssertEqual(monthlyBrackets.current.end, date(2026, 9, 1, hour: 0))
    }

    // MARK: - Exactly at budget

    func testExactlyAtBudgetYieldsZeroRemainingAndFullUtilization() {
        let target: Decimal = 50
        let category = makeCategory(target: target, period: .weekly)
        let entries = [
            entry(20, on: date(2026, 8, 18)),  // Tue
            entry(Decimal(string: "19.99")!, on: date(2026, 8, 19)),  // Wed
            entry(Decimal(string: "10.01")!, on: date(2026, 8, 20)),  // Thu
        ]
        let report = BudgetCalculator.report(
            for: category, entries: entries, calendar: calendar, referenceDate: now
        )!
        XCTAssertEqual(report.currentSpent, target, "exact cents must sum to exact target")
        XCTAssertEqual(report.remaining, Decimal(0))
        // Utilization is exact Decimal division — no accuracy tolerance needed.
        XCTAssertEqual(report.utilization, Decimal(1))
        XCTAssertFalse(report.isOver)
        XCTAssertTrue(report.isWithin, "exactly at target is not overspending")
        // No prior activity + nothing strictly under budget = still a seedling,
        // not a recovery or steady-growth state.
        XCTAssertEqual(report.health, .seedling)
    }

    // MARK: - Overspend

    func testOverspendYieldsNegativeRemainingAndUtilizationOverOne() {
        let target: Decimal = 30
        let category = makeCategory(target: target, period: .weekly)
        let entries = [
            entry(Decimal(string: "25.50")!, on: date(2026, 8, 18)),
            entry(Decimal(string: "10.00")!, on: date(2026, 8, 19)),
        ]
        let report = BudgetCalculator.report(
            for: category, entries: entries, calendar: calendar, referenceDate: now
        )!
        XCTAssertEqual(report.currentSpent, Decimal(string: "35.50")!)
        XCTAssertEqual(report.remaining, Decimal(string: "-5.50")!)
        // 355/300 is the exact quotient of Decimal inputs — asserted exactly.
        XCTAssertEqual(report.utilization, Decimal(string: "35.50")! / Decimal(string: "30")!)
        XCTAssertTrue(report.isOver)
        XCTAssertFalse(report.isWithin)
        XCTAssertEqual(report.health, .wilting, "single overspend with no prior context = wilting")
    }

    // MARK: - Filtering: pending, archived, wrong category

    func testExcludesPendingArchivedAndWrongCategoryEntries() {
        let target: Decimal = 100
        let category = makeCategory(key: "chai", target: target, period: .weekly)
        let entries: [Entry] = [
            // Should count (in range, correct category, confirmed)
            entry(Decimal(string: "10.00")!, on: date(2026, 8, 18), category: "chai"),
            entry(Decimal(string: "5.00")!,  on: date(2026, 8, 19), category: "chai"),
            // Excluded — pending share-sheet import
            entry(Decimal(string: "999.00")!, on: date(2026, 8, 19), category: "chai", isPending: true),
            // Excluded — archived
            entry(Decimal(string: "999.00")!, on: date(2026, 8, 19), category: "chai", isArchived: true),
            // Excluded — wrong category
            entry(Decimal(string: "999.00")!, on: date(2026, 8, 19), category: "food"),
            // Excluded — outside current interval (two weeks ago)
            entry(Decimal(string: "999.00")!, on: date(2026, 8, 3), category: "chai"),
        ]
        let report = BudgetCalculator.report(
            for: category, entries: entries, calendar: calendar, referenceDate: now
        )!
        XCTAssertEqual(report.currentSpent, Decimal(string: "15.00")!)
        XCTAssertEqual(report.currentCount, 2)
        XCTAssertEqual(report.remaining, Decimal(string: "85.00")!)
        // Zero confirmed prior-period entries → first tracked period = seedling
        // (the filtering itself is what this test verifies; see the seedling test
        // below for the no-prior-activity health rule).
        XCTAssertEqual(report.health, .seedling)
    }

    // MARK: - Recovery: prior overspend + current in-budget

    func testPriorOverspendPlusCurrentInBudgetYieldsSprout() {
        let target: Decimal = 40
        let category = makeCategory(target: target, period: .weekly)
        let entries: [Entry] = [
            // Previous week overspend (60 over a 40 target).
            entry(Decimal(string: "60.00")!, on: date(2026, 8, 11)),
            entry(Decimal(string: "10.00")!, on: date(2026, 8, 13)),
            // Current week back in budget (15 of 40).
            entry(Decimal(string: "10.00")!, on: date(2026, 8, 18)),
            entry(Decimal(string: "5.00")!,  on: date(2026, 8, 19)),
        ]
        let report = BudgetCalculator.report(
            for: category, entries: entries, calendar: calendar, referenceDate: now
        )!
        XCTAssertEqual(report.previousSpent, Decimal(string: "70.00")!)
        XCTAssertTrue(report.wasPreviouslyOver)
        XCTAssertEqual(report.currentSpent, Decimal(string: "15.00")!)
        XCTAssertTrue(report.isWithin)
        XCTAssertEqual(report.health, .sprout, "prior overspend + current in-budget = recovery / new growth")
    }

    // MARK: - Regression: recovery requires current-period activity

    func testRecoveryRequiresCurrentPeriodActivity() {
        // Last week blew past the target; this week has zero confirmed entries.
        // Doing nothing must not read as recovery — the period is simply empty.
        let target: Decimal = 40
        let category = makeCategory(target: target, period: .weekly)
        let entries = [entry(Decimal(string: "60.00")!, on: date(2026, 8, 11))]
        let report = BudgetCalculator.report(
            for: category, entries: entries, calendar: calendar, referenceDate: now
        )!
        XCTAssertEqual(report.previousSpent, Decimal(string: "60.00")!)
        XCTAssertTrue(report.wasPreviouslyOver)
        XCTAssertEqual(report.currentSpent, Decimal(0))
        XCTAssertEqual(report.currentCount, 0)
        XCTAssertEqual(
            report.health, .growing,
            "empty current period after an overspend is growth-by-default, not a sprout"
        )
    }

    // MARK: - No-budget path & never-dies guarantee

    func testReportIsNilWhenNoBudgetConfigured() {
        let category = makeCategory(target: nil, period: nil)
        let entries = [entry(10, on: now)]
        XCTAssertNil(BudgetCalculator.report(for: category, entries: entries, calendar: calendar, referenceDate: now))
    }

    func testZeroTargetTreatsCategoryAsUnbudgeted() {
        let category = makeCategory(target: Decimal(0), period: .weekly)
        let entries = [entry(10, on: now)]
        XCTAssertNil(BudgetCalculator.report(for: category, entries: entries, calendar: calendar, referenceDate: now))
    }

    func testNegativeTargetTreatsCategoryAsUnbudgeted() {
        // A negative target is nonsense input; same treatment as zero.
        let category = makeCategory(target: Decimal(string: "-10")!, period: .weekly)
        let entries = [entry(10, on: now)]
        XCTAssertNil(BudgetCalculator.report(for: category, entries: entries, calendar: calendar, referenceDate: now))
    }

    func testReportIsNilWhenTargetSetWithoutExplicitPeriod() {
        // A target without a reset cadence is an incomplete budget — there is no
        // defensible default period, so report must refuse rather than guess.
        let category = makeCategory(target: Decimal(string: "100")!, period: nil)
        let entries = [entry(10, on: now)]
        XCTAssertNil(BudgetCalculator.report(for: category, entries: entries, calendar: calendar, referenceDate: now))
    }

    func testTreeNeverDiesEvenWithChronicOverspend() {
        // Two bad periods in a row — health is `resting`, never a "dead" state.
        let target: Decimal = 20
        let category = makeCategory(target: target, period: .weekly)
        let entries: [Entry] = [
            entry(50, on: date(2026, 8, 11)),
            entry(60, on: date(2026, 8, 19)),
        ]
        let report = BudgetCalculator.report(
            for: category, entries: entries, calendar: calendar, referenceDate: now
        )!
        XCTAssertEqual(report.health, .resting, "chronic overspend must still be a living tree state")
    }

    // MARK: - Decimal safety

    func testTotalsAvoidBinaryFloatDrift() {
        // 0.1 + 0.2 != 0.3 in Double, but Decimal keeps it exact.
        let entries = (0..<10).map { _ in
            entry(Decimal(string: "0.1")!, on: date(2026, 8, 18))
        }
        let category = makeCategory(target: Decimal(string: "100"), period: .weekly)
        let report = BudgetCalculator.report(
            for: category, entries: entries, calendar: calendar, referenceDate: now
        )!
        XCTAssertEqual(report.currentSpent, Decimal(string: "1.0")!, "0.1 × 10 must equal exactly 1.0 in Decimal")
    }

    // MARK: - Seedling (no prior context)

    func testSeedlingWhenCurrentInBudgetButNoPriorActivity() {
        let target: Decimal = 50
        let category = makeCategory(target: target, period: .weekly)
        let entries = [entry(10, on: date(2026, 8, 18))]
        let report = BudgetCalculator.report(
            for: category, entries: entries, calendar: calendar, referenceDate: now
        )!
        XCTAssertEqual(report.previousCount, 0)
        XCTAssertEqual(report.health, .seedling, "first time tracking a category is a seedling")
    }

    // MARK: - Budget configuration changes

    func testIncreasingTargetResetsHealthBaselineWithoutChangingPriorTotals() {
        let category = makeCategory(target: 40, period: .weekly)
        let entries: [Entry] = [
            entry(70, on: date(2026, 8, 11)),
            entry(15, on: date(2026, 8, 18)),
        ]

        let beforeChange = BudgetCalculator.report(
            for: category, entries: entries, calendar: calendar, referenceDate: now
        )!
        XCTAssertEqual(beforeChange.health, .sprout)

        category.budgetTarget = 80
        // Simulate the edit having been saved during the current period. The
        // production property observer supplies this timestamp automatically.
        category.budgetHealthResetDate = date(2026, 8, 19)

        let afterChange = BudgetCalculator.report(
            for: category, entries: entries, calendar: calendar, referenceDate: now
        )!
        XCTAssertEqual(afterChange.previousSpent, Decimal(70))
        XCTAssertEqual(afterChange.previousCount, 1)
        XCTAssertFalse(afterChange.wasPreviouslyOver)
        XCTAssertEqual(afterChange.health, .seedling)
    }

    func testDecreasingTargetResetsHealthBaselineWithoutChangingPriorTotals() {
        let category = makeCategory(target: 100, period: .weekly)
        let entries: [Entry] = [
            entry(70, on: date(2026, 8, 11)),
            entry(15, on: date(2026, 8, 18)),
        ]

        let beforeChange = BudgetCalculator.report(
            for: category, entries: entries, calendar: calendar, referenceDate: now
        )!
        XCTAssertEqual(beforeChange.health, .growing)

        category.budgetTarget = 40
        category.budgetHealthResetDate = date(2026, 8, 19)

        let afterChange = BudgetCalculator.report(
            for: category, entries: entries, calendar: calendar, referenceDate: now
        )!
        XCTAssertEqual(afterChange.previousSpent, Decimal(70))
        XCTAssertEqual(afterChange.previousCount, 1)
        XCTAssertFalse(afterChange.wasPreviouslyOver)
        XCTAssertEqual(afterChange.health, .seedling)
    }

    func testChangingPeriodResetsHealthBaseline() {
        let category = makeCategory(target: 100, period: .weekly)
        let entries = [
            // This is the old weekly context: the prior week was in budget.
            entry(70, on: date(2026, 8, 11)),
            entry(15, on: date(2026, 8, 18)),
            // Under monthly cadence, July was over budget and August is within it.
            entry(150, on: date(2026, 7, 11)),
        ]

        let beforeChange = BudgetCalculator.report(
            for: category, entries: entries, calendar: calendar, referenceDate: now
        )!
        XCTAssertEqual(beforeChange.health, .growing)

        category.budgetPeriod = .monthly
        category.budgetHealthResetDate = date(2026, 8, 19)

        let report = BudgetCalculator.report(
            for: category, entries: entries, calendar: calendar, referenceDate: now
        )!
        XCTAssertEqual(report.period, .monthly)
        XCTAssertEqual(report.currentSpent, Decimal(85))
        XCTAssertEqual(report.previousSpent, Decimal(150))
        XCTAssertFalse(report.wasPreviouslyOver)
        XCTAssertEqual(report.health, .seedling)
    }
}
