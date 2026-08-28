import XCTest
@testable import TapLog

/// When the app offers to plant the first tree, and which category it offers.
final class FirstBudgetTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "FirstBudgetTests"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    /// The state the offer is waiting for: a first log is in, and the categories
    /// beat has been and gone.
    private func seedReadyToOffer() {
        defaults.set(true, forKey: OnboardingFlow.coreCompleteKey)
        defaults.set(true, forKey: OnboardingFlow.categoryPromptDismissedKey)
    }

    private func shouldOffer(logs: Int = 1, hasAnyBudget: Bool = false) -> Bool {
        OnboardingFlow.shouldOfferFirstBudget(
            confirmedLogCount: logs,
            hasAnyBudget: hasAnyBudget,
            defaults: defaults
        )
    }

    // MARK: - When it is offered

    func testOffersOnceTheCategoriesBeatIsDone() {
        seedReadyToOffer()
        XCTAssertTrue(shouldOffer())
    }

    /// "After the categories beat" is the whole placement: the offer names a
    /// category, so asking before the user has said which ones they keep would
    /// name one they are about to delete.
    func testNeverOffersBeforeTheCategoriesBeat() {
        defaults.set(true, forKey: OnboardingFlow.coreCompleteKey)
        XCTAssertFalse(shouldOffer())
    }

    func testNeverOffersBeforeAnythingHasBeenLogged() {
        seedReadyToOffer()
        XCTAssertFalse(shouldOffer(logs: 0))
    }

    /// Someone who already planted a tree found the grove without being asked.
    /// Offering them a "first" budget afterwards reads as the app not looking.
    func testNeverOffersToSomeoneWhoAlreadyHasABudget() {
        seedReadyToOffer()
        XCTAssertFalse(shouldOffer(hasAnyBudget: true))
    }

    /// One offer, ever — declining is an answer, not a postponement.
    func testNeverOffersTwice() {
        seedReadyToOffer()
        XCTAssertTrue(shouldOffer())
        OnboardingFlow.dismissFirstBudget(defaults: defaults)
        XCTAssertFalse(shouldOffer())
    }

    /// Planting from the screen dismisses it the same way skipping does, so the
    /// prompt cannot come back for the budget it just created.
    func testPlantingAlsoClosesTheOfferForGood() {
        seedReadyToOffer()
        OnboardingFlow.dismissFirstBudget(defaults: defaults)
        XCTAssertFalse(shouldOffer(hasAnyBudget: true))
        XCTAssertFalse(shouldOffer(hasAnyBudget: false))
    }

    // MARK: - Which category it names

    private func category(_ key: String, sortOrder: Int) -> SpendCategory {
        SpendCategory(key: key, name: key.capitalized, emoji: "☕️", sortOrder: sortOrder)
    }

    private func entry(_ categoryKey: String) -> Entry {
        Entry(amount: 10, category: categoryKey)
    }

    func testNamesTheMostLoggedCategory() {
        let categories = [category("chai", sortOrder: 0), category("food", sortOrder: 1)]
        let entries = [entry("food"), entry("food"), entry("chai")]

        XCTAssertEqual(
            FirstBudgetPick.category(from: categories, entries: entries)?.key,
            "food"
        )
    }

    /// A tie must not let the offer name a different category each time the view
    /// is rebuilt — the headline would change under the user mid-read.
    func testTiesBreakOnSortOrderRatherThanChanceOrdering() {
        let categories = [category("chai", sortOrder: 0), category("food", sortOrder: 1)]
        let entries = [entry("food"), entry("chai")]

        XCTAssertEqual(
            FirstBudgetPick.category(from: categories, entries: entries)?.key,
            "chai"
        )
        XCTAssertEqual(
            FirstBudgetPick.category(from: categories.reversed(), entries: entries)?.key,
            "chai"
        )
    }

    func testFallsBackToTheFirstCategoryWhenNothingIsLogged() {
        let categories = [category("chai", sortOrder: 0), category("food", sortOrder: 1)]
        XCTAssertEqual(
            FirstBudgetPick.category(from: categories, entries: [])?.key,
            "chai"
        )
    }

    /// Entries in a category the user has since deleted must not win the pick and
    /// leave the screen with nothing to name.
    func testIgnoresEntriesWhoseCategoryIsGone() {
        let categories = [category("chai", sortOrder: 0)]
        let entries = [entry("deleted"), entry("deleted"), entry("chai")]

        XCTAssertEqual(
            FirstBudgetPick.category(from: categories, entries: entries)?.key,
            "chai"
        )
    }

    func testNoCategoriesMeansNothingToOffer() {
        XCTAssertNil(FirstBudgetPick.category(from: [], entries: [entry("chai")]))
    }
}
