import Foundation

/// Durable, versioned first-run state. The core capture loop is intentionally
/// separate from optional education prompts so a prompt can never block logging.
enum OnboardingFlow {
    static let currentVersion = 2

    static let versionKey = "onboardingVersion"
    static let categoryPromptPendingKey = "onboarding.categoryPromptPending"
    static let categoryPromptDismissedKey = "onboarding.categoryPromptDismissed"
    static let fasterPromptDismissedKey = "onboarding.fasterPromptDismissed"
    static let coreCompleteKey = "onboarding.coreComplete"
    static let awaitingFirstConfirmedLogKey = "onboarding.awaitingFirstConfirmedLog"

    static let openCaptureUsedKey = "intent.openCaptureUsed"
    static let logExpenseUsedKey = "intent.logExpenseUsed"
    static let directCaptureUsedKey = "intent.directCaptureUsed"
    static let coreCompletionNotification = Notification.Name("OnboardingFlow.coreCompleted")

    static func migrate(defaults: UserDefaults = .standard) {
        let storedVersion = defaults.integer(forKey: versionKey)
        guard storedVersion < currentVersion else { return }

        let active = defaults.bool(forKey: "onboardingActive")
        let rawStep = defaults.integer(forKey: "onboardingStepRaw")
        if active {
            switch OnboardingStep(rawValue: rawStep) {
            case .categories:
                defaults.set(true, forKey: coreCompleteKey)
                defaults.set(true, forKey: categoryPromptPendingKey)
                defaults.set(false, forKey: categoryPromptDismissedKey)
                defaults.set(false, forKey: "onboardingActive")
            case .frontDoors:
                defaults.set(true, forKey: coreCompleteKey)
                defaults.set(false, forKey: categoryPromptPendingKey)
                defaults.set(false, forKey: "onboardingActive")
                defaults.set(false, forKey: fasterPromptDismissedKey)
            default:
                break
            }
        }

        defaults.set(currentVersion, forKey: versionKey)
    }

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
