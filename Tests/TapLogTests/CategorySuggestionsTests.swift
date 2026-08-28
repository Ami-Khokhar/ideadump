import XCTest
@testable import TapLog

/// Which categories get tiles, and in what order.
///
/// Replaces 584 lines that pinned a Bayesian time-of-day blend. The rule is now
/// small enough to state in a sentence, so the tests are small enough to read.
final class CategorySuggestionsTests: XCTestCase {

    private func category(
        _ key: String,
        sortOrder: Int,
        target: Decimal? = nil,
        period: BudgetPeriod? = nil
    ) -> SpendCategory {
        SpendCategory(
            key: key,
            name: key.capitalized,
            emoji: "☕️",
            sortOrder: sortOrder,
            budgetTarget: target,
            budgetPeriod: period
        )
    }

    private func entries(_ counts: [String: Int]) -> [Entry] {
        counts.flatMap { key, count in
            (0..<count).map { _ in Entry(amount: 10, category: key) }
        }
    }

    private func top(
        _ categories: [SpendCategory],
        _ logs: [String: Int] = [:],
        maxSlots: Int = 4
    ) -> [String] {
        CategorySuggestions.topCategories(
            entries: entries(logs),
            categories: categories,
            maxSlots: maxSlots
        )
    }

    // MARK: - Log count

    func testMostLoggedComesFirst() {
        let categories = [
            category("chai", sortOrder: 0),
            category("food", sortOrder: 1),
            category("metro", sortOrder: 2)
        ]
        XCTAssertEqual(
            top(categories, ["metro": 5, "chai": 1, "food": 3]),
            ["metro", "food", "chai"]
        )
    }

    func testNeverLoggedCategoriesStillGetTiles() {
        // The row always offers its slots. A brand-new install has no history and
        // still needs somewhere to tap.
        let categories = (0..<6).map { category("cat\($0)", sortOrder: $0) }
        XCTAssertEqual(top(categories), ["cat0", "cat1", "cat2", "cat3"])
    }

    // MARK: - Budgets

    func testBudgetedCategoriesLead() {
        let categories = [
            category("chai", sortOrder: 0),
            category("food", sortOrder: 1),
            category("rent", sortOrder: 2, target: 100, period: .monthly)
        ]
        XCTAssertEqual(
            top(categories, ["chai": 9, "food": 4]).first,
            "rent"
        )
    }

    /// The point of leading with budgets: a category you just committed to
    /// tracking has no logs yet, and ranking on logs alone would keep it off the
    /// row forever.
    func testAJustBudgetedCategoryOutranksALongHabit() {
        let categories = [
            category("chai", sortOrder: 0),
            category("gym", sortOrder: 1, target: 50, period: .weekly)
        ]
        XCTAssertEqual(top(categories, ["chai": 40]), ["gym", "chai"])
    }

    func testAmongBudgetsTheMostLoggedStillLeads() {
        let categories = [
            category("chai", sortOrder: 0, target: 40, period: .weekly),
            category("food", sortOrder: 1, target: 100, period: .weekly)
        ]
        XCTAssertEqual(top(categories, ["food": 7, "chai": 2]), ["food", "chai"])
    }

    /// A target with no cadence is an unfinished budget — the grove grows no tree
    /// for it, so it earns no head start here either.
    func testAHalfConfiguredBudgetIsNotABudget() {
        let categories = [
            category("chai", sortOrder: 0),
            category("gym", sortOrder: 1, target: 50, period: nil)
        ]
        XCTAssertEqual(top(categories, ["chai": 1]), ["chai", "gym"])
    }

    func testAZeroTargetIsNotABudget() {
        let categories = [
            category("chai", sortOrder: 0),
            category("gym", sortOrder: 1, target: 0, period: .weekly)
        ]
        XCTAssertEqual(top(categories, ["chai": 1]), ["chai", "gym"])
    }

    // MARK: - Determinism and shape

    /// Equal counts must not sort arbitrarily, or the tiles rearrange themselves
    /// between redraws while the user is looking at them.
    func testEqualCountsFallBackToDisplayOrder() {
        let categories = [
            category("zebra", sortOrder: 0),
            category("apple", sortOrder: 1)
        ]
        XCTAssertEqual(top(categories, ["zebra": 3, "apple": 3]), ["zebra", "apple"])
    }

    func testTheSameInputAlwaysGivesTheSameRow() {
        let categories = (0..<8).map { category("cat\($0)", sortOrder: $0) }
        let logs = ["cat3": 2, "cat5": 2, "cat1": 2]
        let first = top(categories, logs)
        for _ in 0..<20 {
            XCTAssertEqual(top(categories, logs), first)
        }
    }

    func testNeverReturnsMoreThanTheSlotsAsked() {
        let categories = (0..<10).map { category("cat\($0)", sortOrder: $0) }
        XCTAssertEqual(top(categories, [:], maxSlots: 2).count, 2)
        XCTAssertEqual(top(categories, [:], maxSlots: 0).count, 0)
    }

    /// The capture row draws its own "Other" tile; offering it here would show it
    /// twice.
    func testTheFallbackCategoryIsNeverSuggested() {
        let categories = [
            category(SpendCategory.fallbackKey, sortOrder: 0),
            category("chai", sortOrder: 1)
        ]
        let result = top(categories, [SpendCategory.fallbackKey: 50])
        XCTAssertFalse(result.contains(SpendCategory.fallbackKey))
        XCTAssertEqual(result, ["chai"])
    }

    func testNoCategoriesMeansNoTiles() {
        XCTAssertTrue(top([], ["chai": 3]).isEmpty)
    }

    /// Logs against a category the user has since deleted must not conjure a tile
    /// for something that no longer exists.
    func testLogsForADeletedCategoryAreIgnored() {
        let categories = [category("chai", sortOrder: 0)]
        XCTAssertEqual(top(categories, ["deleted": 99, "chai": 1]), ["chai"])
    }
}
