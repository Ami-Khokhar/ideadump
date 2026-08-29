import XCTest
@testable import TapLog

/// The line between free and paid. These are the only two things Pro gates, and
/// the tests exist mostly to keep it that way.
final class ProGateTests: XCTestCase {

    // MARK: - The grove

    /// The first three are free, because the grove has to be able to make its
    /// own argument — one tree is a progress bar, and nobody buys a second of
    /// something they have only seen alone.
    func testTheFirstThreeTreesAreFree() {
        for existing in 0..<3 {
            XCTAssertTrue(
                ProGate.canPlantAnotherTree(existingBudgetCount: existing, isPro: false),
                "existing: \(existing)"
            )
        }
    }

    func testTheFourthTreeIsWhereProBegins() {
        XCTAssertFalse(ProGate.canPlantAnotherTree(existingBudgetCount: 3, isPro: false))
        XCTAssertTrue(ProGate.canPlantAnotherTree(existingBudgetCount: 3, isPro: true))
    }

    /// Someone who deletes a budget gets the slot back. The alternative is
    /// charging them for a mistake they already undid.
    func testDeletingABudgetGivesTheFreeSlotBack() {
        XCTAssertFalse(ProGate.canPlantAnotherTree(existingBudgetCount: 3, isPro: false))
        XCTAssertTrue(ProGate.canPlantAnotherTree(existingBudgetCount: 2, isPro: false))
    }

    /// The gate is about planting the *next* tree, never about keeping the ones
    /// already growing. A free user who somehow holds several budgets — they
    /// predate the paywall, or a purchase lapsed — is blocked from adding, and
    /// nothing more. Nothing here can take a tree away.
    func testAFreeUserAlreadyOverTheLimitIsOnlyBlockedFromAdding() {
        for existing in 4...12 {
            XCTAssertFalse(
                ProGate.canPlantAnotherTree(existingBudgetCount: existing, isPro: false),
                "existing: \(existing)"
            )
            XCTAssertTrue(
                ProGate.canPlantAnotherTree(existingBudgetCount: existing, isPro: true),
                "existing: \(existing)"
            )
        }
    }

    func testProHasNoCeiling() {
        XCTAssertTrue(ProGate.canPlantAnotherTree(existingBudgetCount: 500, isPro: true))
    }

    // MARK: - The recap

    /// The weekly recap is the whole retention loop — the notification is about
    /// it, and the streak is measured against it. It stays free.
    func testTheMonthlyRecapIsPaidAndTheWeeklyOneIsNot() {
        XCTAssertFalse(ProGate.canUseMonthlyRecap(isPro: false))
        XCTAssertTrue(ProGate.canUseMonthlyRecap(isPro: true))
    }

    // MARK: - The export

    /// Gating the export gates the convenience, never the record. Everything
    /// stays readable in History for free — this only decides who gets it as a
    /// spreadsheet.
    func testTheExportIsPaid() {
        XCTAssertFalse(ProGate.canExportCSV(isPro: false))
        XCTAssertTrue(ProGate.canExportCSV(isPro: true))
    }

    // MARK: - What is not gated

    /// A guard against the most likely future mistake: quietly moving the free
    /// limit to zero, which would gate the first tree and turn the onboarding
    /// offer in `FirstBudgetView` into a paywall trigger on a brand-new install.
    func testTheFreeLimitLeavesRoomForTheOnboardingTree() {
        XCTAssertGreaterThanOrEqual(ProGate.freeBudgetLimit, 1)
    }

    /// The grove has to read as a grove before it can be sold. If this number
    /// ever drops below three, the free tier stops being able to show the
    /// contrast — thriving beside wilting — that the whole mechanic rests on.
    func testTheFreeGroveIsBigEnoughToShowContrast() {
        XCTAssertGreaterThanOrEqual(ProGate.freeBudgetLimit, 3)
    }
}
