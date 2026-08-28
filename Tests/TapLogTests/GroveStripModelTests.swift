import XCTest
import Foundation
@testable import TapLog

/// Coverage for the capture screen's grove strip — which categories become
/// trees, in what order, and what the row says about them. Uses the same fixed
/// UTC Monday-first calendar as `BudgetCalculatorTests` so weekly brackets are
/// unambiguous wherever this runs.
final class GroveStripModelTests: XCTestCase {

    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday — matches the app's Monday-first week
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// Wednesday 2026-08-19, mid-week and mid-month.
    private var now: Date { date(2026, 8, 19) }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func category(
        _ key: String,
        target: Decimal? = nil,
        period: BudgetPeriod? = nil
    ) -> SpendCategory {
        SpendCategory(
            key: key,
            name: key.capitalized,
            emoji: "☕️",
            budgetTarget: target,
            budgetPeriod: period
        )
    }

    private func entry(_ amount: Decimal, _ categoryKey: String, on date: Date) -> Entry {
        Entry(amount: amount, category: categoryKey, date: date)
    }

    private func trees(_ categories: [SpendCategory], _ entries: [Entry]) -> [GroveTree] {
        GroveStripModel.trees(
            categories: categories,
            entries: entries,
            calendar: calendar,
            referenceDate: now
        )
    }

    // MARK: - Which categories appear

    /// The strip's visibility rule: no budgets, no trees, so the capture screen
    /// of a fresh install shows no strip at all rather than an empty one.
    func testCategoriesWithoutABudgetProduceNoTrees() {
        let result = trees(
            [category("chai"), category("food")],
            [entry(30, "chai", on: now)]
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testHalfConfiguredBudgetIsNotATree() {
        // A target with no reset cadence is an incomplete budget — there is no
        // period to judge it against, so it must not grow a tree.
        let result = trees([category("chai", target: 100, period: nil)], [])
        XCTAssertTrue(result.isEmpty)
    }

    func testOnlyBudgetedCategoriesBecomeTrees() {
        let result = trees(
            [category("chai", target: 100, period: .weekly), category("food")],
            [entry(30, "chai", on: now), entry(500, "food", on: now)]
        )
        XCTAssertEqual(result.map(\.categoryKey), ["chai"])
    }

    // MARK: - Order

    func testTreesLeadWithTheBudgetUnderTheMostPressure() {
        let result = trees(
            [
                category("chai", target: 100, period: .weekly),
                category("food", target: 100, period: .weekly),
                category("metro", target: 50, period: .weekly)
            ],
            [
                entry(20, "chai", on: now),
                entry(90, "food", on: now),
                entry(100, "metro", on: now)
            ]
        )
        // Metro is at 200% of target, food at 90%, chai at 20%: an overspend is
        // always among the first few, which is what the strip has room to draw.
        XCTAssertEqual(result.map(\.categoryKey), ["metro", "food", "chai"])
    }

    func testUntouchedBudgetsKeepAStableOrder() {
        // Two budgets at zero spend tie on utilization; the key breaks the tie so
        // the row cannot reshuffle itself between redraws.
        let result = trees(
            [
                category("food", target: 100, period: .weekly),
                category("chai", target: 100, period: .weekly)
            ],
            []
        )
        XCTAssertEqual(result.map(\.categoryKey), ["chai", "food"])
    }

    // MARK: - State

    func testOverspendingThisPeriodWilts() {
        let result = trees(
            [category("chai", target: 100, period: .weekly)],
            [entry(140, "chai", on: now)]
        )
        XCTAssertEqual(result.first?.health, .wilting)
        XCTAssertEqual(result.first?.mark, .wilting)
        XCTAssertEqual(result.first?.isOver, true)
    }

    func testStayingWithinTargetIsNeverOver() {
        let result = trees(
            [category("chai", target: 100, period: .weekly)],
            [entry(40, "chai", on: now)]
        )
        XCTAssertEqual(result.first?.health, .seedling)
        XCTAssertEqual(result.first?.isOver, false)
    }

    // MARK: - Captions

    func testSummaryForASingleBudgetNamesItAndItsStatusLine() {
        let result = trees(
            [category("chai", target: 100, period: .weekly)],
            [entry(40, "chai", on: now)]
        )
        // Counting to one says nothing; the row has space for the real number,
        // and for the name of the one tree standing beside it.
        XCTAssertEqual(
            GroveStripModel.summary(for: result),
            "Chai · \(result.first?.detail ?? "")"
        )
    }

    func testSummarySplitsSeveralBudgetsIntoWithinAndOver() {
        let within = trees(
            [
                category("chai", target: 100, period: .weekly),
                category("food", target: 100, period: .weekly)
            ],
            [entry(40, "chai", on: now), entry(50, "food", on: now)]
        )
        XCTAssertEqual(GroveStripModel.summary(for: within), "All within target")

        let mixed = trees(
            [
                category("chai", target: 100, period: .weekly),
                category("food", target: 100, period: .weekly)
            ],
            [entry(40, "chai", on: now), entry(160, "food", on: now)]
        )
        XCTAssertEqual(GroveStripModel.summary(for: mixed), "1 over target")
    }

    func testSummaryOfAnEmptyGroveIsEmpty() {
        XCTAssertEqual(GroveStripModel.summary(for: []), "")
    }

    // MARK: - Accessibility

    /// The strip encodes state as a silhouette and a tint; VoiceOver gets neither,
    /// so every tree has to say which category it is and what state it is in.
    func testEachTreeNamesItsCategoryAndState() {
        let result = trees(
            [category("chai", target: 100, period: .weekly)],
            [entry(140, "chai", on: now)]
        )
        let label = try? XCTUnwrap(result.first?.accessibilityLabel)
        XCTAssertTrue(label?.hasPrefix("Chai, ") == true, "got \(label ?? "nil")")
        XCTAssertTrue(
            label?.contains(BudgetsView.stateWord(for: .wilting)) == true,
            "got \(label ?? "nil")"
        )

        let row = GroveStripModel.accessibilityLabel(for: result)
        XCTAssertTrue(row.contains("Chai"), "got \(row)")
    }

    // MARK: - Log confirmation

    private func tree(_ category: SpendCategory, _ entries: [Entry]) -> GroveTree? {
        GroveStripModel.tree(
            for: category,
            ownEntries: entries,
            calendar: calendar,
            referenceDate: now
        )
    }

    /// The strip and the log confirmation must never disagree, which only holds
    /// while both go through `tree(for:ownEntries:)`.
    func testSingleTreeMatchesTheOneTheStripBuilds() {
        let chai = category("chai", target: 100, period: .weekly)
        let entries = [entry(40, "chai", on: now)]
        XCTAssertEqual(tree(chai, entries), trees([chai], entries).first)
    }

    func testAnUnbudgetedCategoryHasNoTreeToConfirm() {
        XCTAssertNil(tree(category("chai"), [entry(40, "chai", on: now)]))
    }

    /// The confirmation animates only when the entry actually moved the tree, so
    /// a log that lands inside a comfortable budget stays still.
    func testAnEntryInsideTheTargetLeavesTheStateUnchanged() throws {
        let confirmation = try confirmation(logging: 10, target: 100, alreadySpent: 30)
        XCTAssertFalse(confirmation.didChange)
        XCTAssertEqual(confirmation.tree.detail, "₹60.00 left this week")
    }

    /// …and it does move when the entry pushes the category past its target.
    func testAnEntryPastTheTargetMovesTheStateToWilting() throws {
        let confirmation = try confirmation(logging: 90, target: 100, alreadySpent: 30)
        XCTAssertTrue(confirmation.didChange)
        XCTAssertEqual(confirmation.previous.mark, .growing)
        XCTAssertEqual(confirmation.tree.mark, .wilting)
        XCTAssertEqual(confirmation.tree.detail, "₹20.00 over this week")
    }

    /// Mirrors what the capture screen does at save time: derive the tree from
    /// the entries as they stood, then again with the new one added.
    private func confirmation(
        logging amount: Decimal,
        target: Decimal,
        alreadySpent: Decimal
    ) throws -> TreeConfirmation {
        let chai = category("chai", target: target, period: .weekly)
        // A prior week inside the target is what makes the starting state
        // `growing` rather than `seedling`.
        let prior = [
            entry(20, "chai", on: date(2026, 8, 12)),
            entry(alreadySpent, "chai", on: now)
        ]
        return TreeConfirmation(
            tree: try XCTUnwrap(tree(chai, prior + [entry(amount, "chai", on: now)])),
            previous: try XCTUnwrap(tree(chai, prior))
        )
    }
}
