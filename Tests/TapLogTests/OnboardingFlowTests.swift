import XCTest
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

    func testOldCategoryStepMigratesToDeferredPromptWithoutRemainingActive() {
        defaults.set(true, forKey: "onboardingActive")
        defaults.set(OnboardingStep.categories.rawValue, forKey: "onboardingStepRaw")

        OnboardingFlow.migrate(defaults: defaults)

        XCTAssertFalse(defaults.bool(forKey: "onboardingActive"))
        XCTAssertTrue(defaults.bool(forKey: OnboardingFlow.categoryPromptPendingKey))
        XCTAssertEqual(defaults.integer(forKey: OnboardingFlow.versionKey), OnboardingFlow.currentVersion)
    }

    func testOldFrontDoorStepDoesNotMutateCategoryState() {
        defaults.set(true, forKey: "onboardingActive")
        defaults.set(OnboardingStep.frontDoors.rawValue, forKey: "onboardingStepRaw")
        defaults.set(true, forKey: "categoryWasCustomized")

        OnboardingFlow.migrate(defaults: defaults)

        XCTAssertFalse(defaults.bool(forKey: "onboardingActive"))
        XCTAssertTrue(defaults.bool(forKey: "categoryWasCustomized"))
        XCTAssertFalse(defaults.bool(forKey: OnboardingFlow.fasterPromptDismissedKey))
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

    func testLegacyFrontDoorsMigrationPrecedesConfirmedReconciliation() {
        defaults.set(true, forKey: "onboardingActive")
        defaults.set(OnboardingStep.frontDoors.rawValue, forKey: "onboardingStepRaw")

        OnboardingFlow.migrate(defaults: defaults)

        XCTAssertTrue(defaults.bool(forKey: OnboardingFlow.coreCompleteKey))
        XCTAssertFalse(defaults.bool(forKey: OnboardingFlow.categoryPromptPendingKey))
        XCTAssertFalse(defaults.bool(forKey: OnboardingFlow.fasterPromptDismissedKey))

        XCTAssertFalse(OnboardingFlow.reconcileCoreIfNeeded(
            confirmedLogCount: 1,
            onboardingActive: false,
            defaults: defaults
        ))
        XCTAssertTrue(OnboardingFlow.shouldOfferFasterWays(
            confirmedLogCount: 2,
            isFirstLogSession: false,
            defaults: defaults
        ))
    }

    func testLegacyCategoriesMigrationPreservesCategoryPromptAfterReconciliation() {
        defaults.set(true, forKey: "onboardingActive")
        defaults.set(OnboardingStep.categories.rawValue, forKey: "onboardingStepRaw")

        OnboardingFlow.migrate(defaults: defaults)

        XCTAssertTrue(defaults.bool(forKey: OnboardingFlow.categoryPromptPendingKey))
        XCTAssertFalse(OnboardingFlow.reconcileCoreIfNeeded(
            confirmedLogCount: 1,
            onboardingActive: false,
            defaults: defaults
        ))
        XCTAssertTrue(defaults.bool(forKey: OnboardingFlow.categoryPromptPendingKey))
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
