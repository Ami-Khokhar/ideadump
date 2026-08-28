import Foundation

/// Durable, versioned first-run state. The core capture loop is intentionally
/// separate from optional education prompts so a prompt can never block logging.
enum OnboardingFlow {
    static let categoryPromptPendingKey = "onboarding.categoryPromptPending"
    static let categoryPromptDismissedKey = "onboarding.categoryPromptDismissed"
    static let fasterPromptDismissedKey = "onboarding.fasterPromptDismissed"
    static let firstBudgetPromptDismissedKey = "onboarding.firstBudgetPromptDismissed"
    static let coreCompleteKey = "onboarding.coreComplete"
    static let awaitingFirstConfirmedLogKey = "onboarding.awaitingFirstConfirmedLog"

    /// Feature explainers are shown once, the first time the user opens the
    /// feature itself, and are reachable from its toolbar afterwards. They are
    /// deliberately not part of the `DeferredPrompt` machinery: those interrupt
    /// the capture screen, these only ever appear on a screen the user chose to
    /// open, so they cost nothing to a user who never goes looking.
    static let budgetsExplainerSeenKey = "onboarding.budgetsExplainerSeen"
    static let recapExplainerSeenKey = "onboarding.recapExplainerSeen"

    static let openCaptureUsedKey = "intent.openCaptureUsed"
    static let logExpenseUsedKey = "intent.logExpenseUsed"
    static let directCaptureUsedKey = "intent.directCaptureUsed"
    static let coreCompletionNotification = Notification.Name("OnboardingFlow.coreCompleted")

    static func markCoreComplete(defaults: UserDefaults = .standard) {
        let wasComplete = defaults.bool(forKey: coreCompleteKey)
        guard !wasComplete else {
            defaults.set(false, forKey: "onboardingActive")
            defaults.set(false, forKey: awaitingFirstConfirmedLogKey)
            return
        }
        defaults.set(true, forKey: coreCompleteKey)
        defaults.set(true, forKey: categoryPromptPendingKey)
        defaults.set(false, forKey: categoryPromptDismissedKey)
        defaults.set(false, forKey: "onboardingActive")
        defaults.set(false, forKey: awaitingFirstConfirmedLogKey)
        NotificationCenter.default.post(name: coreCompletionNotification, object: nil)
    }

    static func shouldAwaitFirstConfirmedLog(
        coreComplete: Bool,
        confirmedLogCount: Int
    ) -> Bool {
        !coreComplete
            && confirmedLogCount == 0
    }

    static func markAwaitingFirstConfirmedLog(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: coreCompleteKey) else { return }
        defaults.set(true, forKey: awaitingFirstConfirmedLogKey)
    }

    static func markCoreCompleteIfConfirmed(
        isPending: Bool,
        isArchived: Bool,
        defaults: UserDefaults = .standard
    ) {
        guard !isPending, !isArchived else { return }
        markCoreComplete(defaults: defaults)
    }

    static func reconcileCoreIfNeeded(
        confirmedLogCount: Int,
        onboardingActive: Bool,
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard confirmedLogCount > 0,
              !defaults.bool(forKey: coreCompleteKey) else { return false }
        let awaiting = defaults.bool(forKey: awaitingFirstConfirmedLogKey)
        guard onboardingActive || awaiting else { return false }
        markCoreComplete(defaults: defaults)
        return true
    }

    static func canScheduleDeferredPrompts(
        onboardingActive: Bool,
        hasOnboardingCover: Bool,
        routeActive: Bool,
        deferredPromptActive: Bool,
        activeDeferredPrompt: Bool,
        prefillActive: Bool,
        loggedInCurrentSession: Bool,
        suppressForCurrentSession: Bool
    ) -> Bool {
        !onboardingActive
            && !hasOnboardingCover
            && !routeActive
            && !deferredPromptActive
            && !activeDeferredPrompt
            && !prefillActive
            && !loggedInCurrentSession
            && !suppressForCurrentSession
    }

    static func shouldOfferCategories(
        confirmedLogCount: Int,
        defaults: UserDefaults = .standard
    ) -> Bool {
        confirmedLogCount > 0
            && defaults.bool(forKey: coreCompleteKey)
            && defaults.bool(forKey: categoryPromptPendingKey)
            && !defaults.bool(forKey: categoryPromptDismissedKey)
    }

    static func confirmedLogCount(_ entries: [Entry]) -> Int {
        entries.reduce(into: 0) { count, entry in
            if !entry.isArchived && !entry.isPending { count += 1 }
        }
    }

    static func dismissCategories(defaults: UserDefaults = .standard) {
        defaults.set(false, forKey: categoryPromptPendingKey)
        defaults.set(true, forKey: categoryPromptDismissedKey)
    }

    /// Whether to offer to plant the first tree.
    ///
    /// Follows the categories beat rather than replacing it: the offer names a
    /// category, so it is worth asking only once the user has had their say about
    /// which categories they keep. It is also skipped entirely for anyone who
    /// already has a budget — that user found the grove without being asked, and
    /// being offered a "first" tree afterwards would read as the app not looking.
    static func shouldOfferFirstBudget(
        confirmedLogCount: Int,
        hasAnyBudget: Bool,
        defaults: UserDefaults = .standard
    ) -> Bool {
        confirmedLogCount > 0
            && !hasAnyBudget
            && defaults.bool(forKey: coreCompleteKey)
            && defaults.bool(forKey: categoryPromptDismissedKey)
            && !defaults.bool(forKey: firstBudgetPromptDismissedKey)
    }

    static func dismissFirstBudget(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: firstBudgetPromptDismissedKey)
    }

    static func shouldOfferFasterWays(
        confirmedLogCount: Int,
        isFirstLogSession: Bool,
        defaults: UserDefaults = .standard
    ) -> Bool {
        confirmedLogCount >= 2
            && !isFirstLogSession
            && !defaults.bool(forKey: fasterPromptDismissedKey)
    }

    static func dismissFasterWays(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: fasterPromptDismissedKey)
    }

    /// True until the explainer for `key` has been shown once.
    static func shouldShowExplainer(_ key: String, defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: key)
    }

    static func markExplainerSeen(_ key: String, defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key)
    }

    static func recordIntentUse(_ key: String, defaults: UserDefaults = StoreLocator.sharedDefaults) {
        defaults.set(true, forKey: key)
        defaults.set(Date(), forKey: "\(key).lastUsedAt")
    }

    static func directCaptureStatus(openCaptureUsed: Bool, directCaptureUsed: Bool) -> String? {
        if openCaptureUsed { return "Open Expense Capture used" }
        if directCaptureUsed { return "Direct capture used" }
        return nil
    }
}
