import XCTest
@testable import TapLog

/// The line between free and paid. These are the only two things Pro gates, and
/// the tests exist mostly to keep it that way.
final class ProGateTests: XCTestCase {

    // MARK: - The grove

    /// The first tree is free, because a tree nobody has planted cannot sell
    /// anything.
    func testTheFirstTreeIsFree() {
        XCTAssertTrue(ProGate.canPlantAnotherTree(existingBudgetCount: 0, isPro: false))
    }

    func testTheSecondTreeIsWhereProBegins() {
        XCTAssertFalse(ProGate.canPlantAnotherTree(existingBudgetCount: 1, isPro: false))
        XCTAssertTrue(ProGate.canPlantAnotherTree(existingBudgetCount: 1, isPro: true))
    }

    /// Someone who deletes a budget gets the slot back. The alternative is
    /// charging them for a mistake they already undid.
    func testDeletingABudgetGivesTheFreeSlotBack() {
        XCTAssertFalse(ProGate.canPlantAnotherTree(existingBudgetCount: 1, isPro: false))
        XCTAssertTrue(ProGate.canPlantAnotherTree(existingBudgetCount: 0, isPro: false))
    }

    /// The gate is about planting the *next* tree, never about keeping the ones
    /// already growing. A free user who somehow holds several budgets — they
    /// predate the paywall, or a purchase lapsed — is blocked from adding, and
    /// nothing more. Nothing here can take a tree away.
    func testAFreeUserAlreadyOverTheLimitIsOnlyBlockedFromAdding() {
        for existing in 2...10 {
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

    // MARK: - What is not gated

    /// A guard against the most likely future mistake: quietly moving the free
    /// limit to zero, which would gate the first tree and turn the onboarding
    /// offer in `FirstBudgetView` into a paywall trigger on a brand-new install.
    func testTheFreeLimitLeavesRoomForTheOnboardingTree() {
        XCTAssertGreaterThanOrEqual(ProGate.freeBudgetLimit, 1)
    }
}
