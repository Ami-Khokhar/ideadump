import XCTest
@testable import TapLog

/// These buttons log money on one tap with no confirmation, so their order is
/// behaviour, not presentation: a button that moves between refreshes turns a
/// tap aimed at chai into rent.
final class QuickButtonRankingTests: XCTestCase {
    private func pattern(_ key: String, _ amount: Decimal) -> QuickButtonRanking.Pattern {
        QuickButtonRanking.Pattern(categoryKey: key, amount: amount)
    }

    func testMostRepeatedComesFirst() {
        let counts = [
            pattern("chai", 45): 2,
            pattern("rent", 120): 9,
            pattern("bus", 30): 5
        ]
        XCTAssertEqual(
            QuickButtonRanking.top(counts),
            [pattern("rent", 120), pattern("bus", 30), pattern("chai", 45)]
        )
    }

    /// The new-user case, and the one the old frequency-only sort got wrong:
    /// every count is 1, so every comparison is a tie.
    func testAllTiesStillProduceOneFixedOrder() {
        let counts = [
            pattern("rent", 120): 1,
            pattern("chai", 45): 1,
            pattern("bus", 30): 1,
            pattern("food", 200): 1
        ]
        let first = QuickButtonRanking.top(counts)
        XCTAssertEqual(first, [pattern("bus", 30), pattern("chai", 45), pattern("food", 200)])

        // Rebuilding the dictionary changes its iteration order; the result
        // must not follow it. This is what a widget process relaunch does.
        for _ in 0..<50 {
            var rebuilt: [QuickButtonRanking.Pattern: Int] = [:]
            for (key, value) in counts.shuffled() { rebuilt[key] = value }
            XCTAssertEqual(QuickButtonRanking.top(rebuilt), first)
        }
    }

    func testTwoAmountsInOneCategoryTieOnTheAmount() {
        let counts = [
            pattern("chai", 80): 3,
            pattern("chai", 45): 3
        ]
        XCTAssertEqual(
            QuickButtonRanking.top(counts),
            [pattern("chai", 45), pattern("chai", 80)]
        )
    }

    func testEmptyHistoryRanksNothing() {
        XCTAssertTrue(QuickButtonRanking.top([:]).isEmpty)
    }

    func testFewerPatternsThanTheLimitIsNotPadded() {
        let counts = [pattern("chai", 45): 4]
        XCTAssertEqual(QuickButtonRanking.top(counts), [pattern("chai", 45)])
    }
}
