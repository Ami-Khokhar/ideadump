import XCTest
import SwiftData
@testable import TapLog

final class OnboardingFlowTests: XCTestCase {
    private let suiteName = "test.OnboardingFlow"
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

    func testCoreCompletionDoesNotOfferSetupImmediately() {
        OnboardingFlow.markCoreComplete(defaults: defaults)

        XCTAssertTrue(OnboardingFlow.shouldOfferCategories(confirmedLogCount: 1, defaults: defaults))
        XCTAssertFalse(OnboardingFlow.shouldOfferFasterWays(
            confirmedLogCount: 2,
            isFirstLogSession: true,
            defaults: defaults
        ))
    }

    func testCategoryPromptDismissalPersists() {
        OnboardingFlow.markCoreComplete(defaults: defaults)
        XCTAssertTrue(OnboardingFlow.shouldOfferCategories(confirmedLogCount: 1, defaults: defaults))

        OnboardingFlow.dismissCategories(defaults: defaults)

        XCTAssertFalse(OnboardingFlow.shouldOfferCategories(confirmedLogCount: 1, defaults: defaults))
        XCTAssertTrue(defaults.bool(forKey: OnboardingFlow.categoryPromptDismissedKey))

        OnboardingFlow.markCoreCompleteIfConfirmed(isPending: false, isArchived: false, defaults: defaults)

        XCTAssertFalse(defaults.bool(forKey: OnboardingFlow.categoryPromptPendingKey))
        XCTAssertTrue(defaults.bool(forKey: OnboardingFlow.categoryPromptDismissedKey))
    }

    func testFasterWaysRequiresTwoLogsAndAnotherSession() {
        XCTAssertFalse(OnboardingFlow.shouldOfferFasterWays(
            confirmedLogCount: 1,
            isFirstLogSession: false,
            defaults: defaults
        ))
        XCTAssertFalse(OnboardingFlow.shouldOfferFasterWays(
            confirmedLogCount: 2,
            isFirstLogSession: true,
            defaults: defaults
        ))
        XCTAssertTrue(OnboardingFlow.shouldOfferFasterWays(
            confirmedLogCount: 2,
            isFirstLogSession: false,
            defaults: defaults
        ))
    }

    func testPendingAndArchivedEntriesDoNotCompleteCoreCapture() {
        let entries = [
            Entry(amount: 1, category: "chai", isPending: true),
            Entry(amount: 2, category: "food", isArchived: true),
            Entry(amount: 3, category: "transport")
        ]

        XCTAssertEqual(OnboardingFlow.confirmedLogCount(entries), 1)
    }

    func testShareConfirmationCompletesCoreOnlyAfterConfirmation() {
        OnboardingFlow.markCoreCompleteIfConfirmed(isPending: true, isArchived: false, defaults: defaults)
        XCTAssertFalse(defaults.bool(forKey: OnboardingFlow.coreCompleteKey))

        OnboardingFlow.markCoreCompleteIfConfirmed(isPending: false, isArchived: true, defaults: defaults)
        XCTAssertFalse(defaults.bool(forKey: OnboardingFlow.coreCompleteKey))

        OnboardingFlow.markCoreCompleteIfConfirmed(isPending: false, isArchived: false, defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: OnboardingFlow.coreCompleteKey))
    }

    func testIntentUseFlagsAreRecordedInSharedState() {
        OnboardingFlow.recordIntentUse(OnboardingFlow.openCaptureUsedKey, defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: OnboardingFlow.openCaptureUsedKey))
        XCTAssertNotNil(defaults.object(forKey: "\(OnboardingFlow.openCaptureUsedKey).lastUsedAt"))
    }

    func testOpenCaptureOptionalAmountRejectsInvalidValues() throws {
        XCTAssertNil(try OpenCaptureIntent.prefillAmountText(from: nil))
        XCTAssertEqual(try OpenCaptureIntent.prefillAmountText(from: 12.5), "12.5")
        XCTAssertThrowsError(try OpenCaptureIntent.prefillAmountText(from: 0))
        XCTAssertThrowsError(try OpenCaptureIntent.prefillAmountText(from: -1))
    }

    func testUnknownIntentCategoryFallsBackToOther() {
        let categories = [SpendCategory(key: "chai", name: "Chai", emoji: "☕️")]
        XCTAssertEqual(
            LogExpenseIntent.resolveCategoryKey("unknown", categories: categories),
            SpendCategory.fallbackKey
        )
        XCTAssertEqual(
            LogExpenseIntent.resolveCategoryKey("chai", categories: categories),
            "chai"
        )
    }

    // MARK: - Siri category resolution

    private var siriCategories: [SpendCategory] {
        [
            SpendCategory(key: "chai", name: "Chai", emoji: "☕️"),
            SpendCategory(key: "metro", name: "Metro", emoji: "🚇"),
        ]
    }

    func testSpokenCategoryWins() {
        XCTAssertEqual(
            LogExpenseIntent.resolvedKey(
                entity: CategoryEntity(id: "metro", name: "Metro", emoji: "🚇"),
                categories: siriCategories
            ),
            "metro",
            "a category named in the phrase resolves directly to its entity key"
        )
    }

    func testRequiredCategoryResolvesToItsEntityKey() {
        XCTAssertEqual(
            LogExpenseIntent.resolvedKey(
                entity: CategoryEntity(id: "chai", name: "Chai", emoji: "☕️"),
                categories: siriCategories
            ),
            "chai"
        )
    }

    func testDeletedCategoriesFallThroughToOther() {
        // A shortcut built against a category the user has since deleted must
        // degrade rather than resurrect the key.
        XCTAssertEqual(
            LogExpenseIntent.resolvedKey(
                entity: CategoryEntity(id: "removed", name: "Removed", emoji: "❓"),
                categories: siriCategories
            ),
            SpendCategory.fallbackKey
        )
        XCTAssertEqual(
            LogExpenseIntent.resolvedKey(
                entity: CategoryEntity(id: "alsoRemoved", name: "Also Removed", emoji: "❓"),
                categories: siriCategories
            ),
            SpendCategory.fallbackKey
        )
    }

    // MARK: - Log Expense shortcut

    func testNoteAnswerSkipsOnEmptyOrSkipWord() {
        XCTAssertNil(LogExpenseIntent.cleanedNote(nil))
        XCTAssertNil(LogExpenseIntent.cleanedNote(""))
        XCTAssertNil(LogExpenseIntent.cleanedNote("   "))
        XCTAssertNil(LogExpenseIntent.cleanedNote("skip"))
        XCTAssertNil(LogExpenseIntent.cleanedNote("Skip."), "Siri's transcription of a spoken skip")
        XCTAssertNil(LogExpenseIntent.cleanedNote("No"))
        XCTAssertNil(LogExpenseIntent.cleanedNote("nothing"))
        XCTAssertNil(LogExpenseIntent.cleanedNote("-"))
        XCTAssertEqual(LogExpenseIntent.cleanedNote("  dinner with Raj "), "dinner with Raj")
        XCTAssertEqual(LogExpenseIntent.cleanedNote("no sugar"), "no sugar", "only a whole-answer skip word is dropped")
    }

    /// The category question lists `suggestedEntities()`. It used to stop at 8,
    /// so with the 13 default categories "Rent" and friends could not be picked.
    @MainActor
    func testCategoryQuestionOffersEveryCategory() async throws {
        let context = try StoreLocator.container().mainContext
        let stored = try context.fetchCount(FetchDescriptor<SpendCategory>())
        XCTAssertGreaterThan(stored, 8, "the test host seeds the default categories")

        let offered = try await CategoryEntityQuery().suggestedEntities()
        XCTAssertEqual(offered.count, stored)
    }

    /// Runs the real intent against the real store: amount, category and note
    /// land in one entry the app reads.
    @MainActor
    func testLogExpenseIntentSavesEntryToStore() async throws {
        let context = try StoreLocator.container().mainContext
        let categories = try context.fetch(FetchDescriptor<SpendCategory>())
        let chai = try XCTUnwrap(categories.first { $0.key == "chai" })
        let note = "intent-test-\(UUID().uuidString)"

        var intent = LogExpenseIntent()
        intent.amount = 42.5
        intent.category = CategoryEntity(id: chai.key, name: chai.name, emoji: chai.emoji)
        intent.note = "  \(note) "
        intent.askForNote = true // a note passed in must not be asked again
        _ = try await intent.perform()

        let saved = try context.fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.note == note }))
        XCTAssertEqual(saved.count, 1)
        let entry = try XCTUnwrap(saved.first)
        XCTAssertEqual(entry.amount, Decimal(string: "42.5"))
        XCTAssertEqual(entry.category, "chai")
        XCTAssertFalse(entry.isPending)

        // Leave the simulator's store as we found it.
        context.delete(entry)
        try context.save()
        CaptureBookkeeping.revert(modelContext: context, categories: categories, categoryKey: "chai", entryDate: entry.date)
    }

    @MainActor
    func testLogExpenseIntentRejectsZeroAmountWithoutSaving() async throws {
        let context = try StoreLocator.container().mainContext
        let before = try context.fetchCount(FetchDescriptor<Entry>())

        var intent = LogExpenseIntent()
        intent.amount = 0
        intent.category = CategoryEntity(id: "chai", name: "Chai", emoji: "☕️")
        intent.askForNote = false
        do {
            _ = try await intent.perform()
            XCTFail("a zero amount must be asked for again, not logged")
        } catch {}

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Entry>()), before)
    }

    // MARK: - Widget quick-log

    /// The widget's buttons run `QuickLogIntent` in the widget's own process.
    /// Nothing covered it, so this runs it against the real store the way a tap does.
    @MainActor
    func testWidgetQuickLogSavesEntry() async throws {
        let context = try StoreLocator.container().mainContext
        let categories = try context.fetch(FetchDescriptor<SpendCategory>())
        let chai = try XCTUnwrap(categories.first { $0.key == "chai" })
        let marker = Decimal(string: "4242.42")!

        _ = try await QuickLogIntent(amount: 4242.42, category: chai.key).perform()

        let saved = try context.fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.amount == marker }))
        XCTAssertEqual(saved.count, 1)
        let entry = try XCTUnwrap(saved.first)
        XCTAssertEqual(entry.category, "chai")
        XCTAssertNil(entry.note, "a widget tap carries no note")
        XCTAssertFalse(entry.isPending)

        context.delete(entry)
        try context.save()
        CaptureBookkeeping.revert(modelContext: context, categories: categories, categoryKey: "chai", entryDate: entry.date)
    }

    /// A widget built against a category the user has since deleted must file the
    /// expense under Other rather than lose it.
    @MainActor
    func testWidgetQuickLogFallsBackToOtherForDeletedCategory() async throws {
        let context = try StoreLocator.container().mainContext
        let categories = try context.fetch(FetchDescriptor<SpendCategory>())
        let marker = Decimal(string: "4343.43")!

        _ = try await QuickLogIntent(amount: 4343.43, category: "deleted-category").perform()

        let saved = try context.fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.amount == marker }))
        let entry = try XCTUnwrap(saved.first)
        XCTAssertEqual(entry.category, SpendCategory.fallbackKey)

        context.delete(entry)
        try context.save()
        CaptureBookkeeping.revert(
            modelContext: context,
            categories: categories,
            categoryKey: SpendCategory.fallbackKey,
            entryDate: entry.date
        )
    }

    @MainActor
    func testWidgetQuickLogRejectsInvalidAmountWithoutSaving() async throws {
        let context = try StoreLocator.container().mainContext
        let before = try context.fetchCount(FetchDescriptor<Entry>())

        do {
            _ = try await QuickLogIntent(amount: 0, category: "chai").perform()
            XCTFail("a zero amount must not be logged")
        } catch {}

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Entry>()), before)
    }

    func testAmountLayoutRemainsBoundedAndGrowsWithText() {
        let short = AmountLayout.fieldWidth(text: "12", fontSize: 56, maxWidth: 260)
        let long = AmountLayout.fieldWidth(text: "999999999.99", fontSize: 34, maxWidth: 260)
        let capped = AmountLayout.fieldWidth(text: "999999999999999", fontSize: 34, maxWidth: 120)

        XCTAssertGreaterThan(long, short)
        XCTAssertLessThanOrEqual(capped, 120)
    }

    func testDirectCaptureStatusNeverLabelsDeepLinkAsSiri() {
        XCTAssertEqual(
            OnboardingFlow.directCaptureStatus(openCaptureUsed: false, directCaptureUsed: true),
            "Direct capture used"
        )
        XCTAssertEqual(
            OnboardingFlow.directCaptureStatus(openCaptureUsed: true, directCaptureUsed: true),
            "Open Expense Capture used"
        )
        XCTAssertNil(OnboardingFlow.directCaptureStatus(openCaptureUsed: false, directCaptureUsed: false))
    }

    func testCoreCompletionNotificationPostsOnlyOnFirstTransition() {
        let first = expectation(description: "first core completion")
        let token = NotificationCenter.default.addObserver(
            forName: OnboardingFlow.coreCompletionNotification,
            object: nil,
            queue: .main
        ) { _ in first.fulfill() }
        defer { NotificationCenter.default.removeObserver(token) }

        OnboardingFlow.markCoreComplete(defaults: defaults)
        wait(for: [first], timeout: 1)

        let second = expectation(description: "no duplicate completion")
        second.isInverted = true
        let secondToken = NotificationCenter.default.addObserver(
            forName: OnboardingFlow.coreCompletionNotification,
            object: nil,
            queue: .main
        ) { _ in second.fulfill() }
        defer { NotificationCenter.default.removeObserver(secondToken) }
        OnboardingFlow.markCoreComplete(defaults: defaults)
        wait(for: [second], timeout: 0.1)
    }

    func testHeadlessConfirmedEntryReconcilesActiveOnboarding() {
        defaults.set(false, forKey: OnboardingFlow.coreCompleteKey)

        XCTAssertTrue(OnboardingFlow.reconcileCoreIfNeeded(
            confirmedLogCount: 1,
            onboardingActive: true,
            defaults: defaults
        ))
        XCTAssertTrue(defaults.bool(forKey: OnboardingFlow.coreCompleteKey))
    }

    func testDirectActivationWaitsForFirstConfirmedEntry() {
        XCTAssertTrue(OnboardingFlow.shouldAwaitFirstConfirmedLog(
            coreComplete: false,
            confirmedLogCount: 0
        ))
        OnboardingFlow.markAwaitingFirstConfirmedLog(defaults: defaults)

        XCTAssertFalse(OnboardingFlow.reconcileCoreIfNeeded(
            confirmedLogCount: 0,
            onboardingActive: false,
            defaults: defaults
        ))
        XCTAssertFalse(defaults.bool(forKey: OnboardingFlow.coreCompleteKey))

        XCTAssertTrue(OnboardingFlow.reconcileCoreIfNeeded(
            confirmedLogCount: 1,
            onboardingActive: false,
            defaults: defaults
        ))
        XCTAssertTrue(defaults.bool(forKey: OnboardingFlow.coreCompleteKey))
        XCTAssertFalse(defaults.bool(forKey: OnboardingFlow.awaitingFirstConfirmedLogKey))
    }

    func testDirectActivationWithNoOnboardingOrFirstEntryDoesNotAwaitOrComplete() {
        XCTAssertFalse(OnboardingFlow.shouldAwaitFirstConfirmedLog(
            coreComplete: false,
            confirmedLogCount: 1
        ))
        XCTAssertFalse(OnboardingFlow.reconcileCoreIfNeeded(
            confirmedLogCount: 0,
            onboardingActive: false,
            defaults: defaults
        ))
        XCTAssertFalse(defaults.bool(forKey: OnboardingFlow.coreCompleteKey))
    }

    func testPersistedAwaitingMarkerReconcilesOnColdRelaunchWhenEntryExists() {
        defaults.set(true, forKey: OnboardingFlow.awaitingFirstConfirmedLogKey)

        XCTAssertTrue(OnboardingFlow.reconcileCoreIfNeeded(
            confirmedLogCount: 1,
            onboardingActive: false,
            defaults: defaults
        ))
        XCTAssertTrue(defaults.bool(forKey: OnboardingFlow.coreCompleteKey))
        XCTAssertFalse(defaults.bool(forKey: OnboardingFlow.awaitingFirstConfirmedLogKey))
    }

    func testPersistedAwaitingMarkerDoesNotCompleteColdRelaunchWithoutEntry() {
        defaults.set(true, forKey: OnboardingFlow.awaitingFirstConfirmedLogKey)

        XCTAssertFalse(OnboardingFlow.reconcileCoreIfNeeded(
            confirmedLogCount: 0,
            onboardingActive: false,
            defaults: defaults
        ))
        XCTAssertFalse(defaults.bool(forKey: OnboardingFlow.coreCompleteKey))
        XCTAssertTrue(defaults.bool(forKey: OnboardingFlow.awaitingFirstConfirmedLogKey))
    }

    func testReconciliationIgnoresZeroOrAlreadyCompleteState() {
        XCTAssertFalse(OnboardingFlow.reconcileCoreIfNeeded(
            confirmedLogCount: 0,
            onboardingActive: true,
            defaults: defaults
        ))
        defaults.set(true, forKey: OnboardingFlow.coreCompleteKey)
        XCTAssertFalse(OnboardingFlow.reconcileCoreIfNeeded(
            confirmedLogCount: 1,
            onboardingActive: true,
            defaults: defaults
        ))
    }

    func testDeferredPromptArbitrationSuppressesCurrentSessionCompetition() {
        XCTAssertFalse(OnboardingFlow.canScheduleDeferredPrompts(
            onboardingActive: false,
            hasOnboardingCover: false,
            routeActive: true,
            deferredPromptActive: false,
            activeDeferredPrompt: false,
            prefillActive: false,
            loggedInCurrentSession: false,
            suppressForCurrentSession: false
        ))
        XCTAssertFalse(OnboardingFlow.canScheduleDeferredPrompts(
            onboardingActive: false,
            hasOnboardingCover: false,
            routeActive: false,
            deferredPromptActive: false,
            activeDeferredPrompt: false,
            prefillActive: false,
            loggedInCurrentSession: false,
            suppressForCurrentSession: true
        ))
    }

    func testDynamicTypeScalesShortHeroButKeepsLongValueReadable() {
        let normal = AmountFont.fontSize(for: "12", dynamicTypeSize: .large)
        let accessibility = AmountFont.fontSize(for: "12", dynamicTypeSize: .accessibility3)
        let long = AmountFont.fontSize(for: "999999999.99", dynamicTypeSize: .accessibility3)

        XCTAssertGreaterThan(accessibility, normal)
        XCTAssertGreaterThanOrEqual(long, AmountFont.minFontSize)
        XCTAssertLessThanOrEqual(accessibility, 76)
    }

    func testDynamicTypeHeroAndFieldHeightsGrowTogetherWithinBounds() {
        let regularField = AmountLayout.fieldHeight(fontSize: 56)
        let accessibilityField = AmountLayout.fieldHeight(fontSize: 76)
        let regularHero = AmountLayout.heroHeight(fontSize: 56)
        let accessibilityHero = AmountLayout.heroHeight(fontSize: 76)

        XCTAssertGreaterThan(accessibilityField, regularField)
        XCTAssertGreaterThan(accessibilityHero, regularHero)
        XCTAssertLessThanOrEqual(accessibilityField, 104)
        XCTAssertLessThanOrEqual(accessibilityHero, 132)
        XCTAssertGreaterThanOrEqual(AmountLayout.heroHeight(fontSize: 34), 92)
    }

    func testGroupedMaximumFitsA320PointViewportWithResponsiveFloor() {
        let amount = "999,999,999.99"
        let viewportWidth: CGFloat = 320
        let symbolWidth: CGFloat = 18
        let maxFieldWidth = viewportWidth - symbolWidth - 34
        let fieldWidth = AmountLayout.fieldWidth(
            text: amount,
            fontSize: 34,
            maxWidth: maxFieldWidth
        )
        let minimum = AmountLayout.minimumFontSize(
            text: amount,
            fontSize: 34,
            availableWidth: fieldWidth
        )

        XCTAssertLessThan(minimum, AmountFont.minFontSize)
        XCTAssertGreaterThanOrEqual(minimum, AmountLayout.longValueFontFloor)
        XCTAssertLessThanOrEqual(
            AmountLayout.measuredTextWidth(text: amount, fontSize: minimum) + 10,
            fieldWidth + 0.5
        )
    }
}
