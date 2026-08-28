import Foundation
import UserNotifications

/// When TapLog is allowed to ask for notification permission.
///
/// Never at launch. A permission sheet on first open is a toll collected before
/// the app has done anything for anyone, and it is the one prompt that cannot be
/// asked twice — a "no" there is permanent, and it takes the weekly recap with
/// it. So the ask waits for a moment the notification has visibly earned: the
/// user has read a recap and knows what one is, or they have finished a week and
/// there is now something worth telling them about.
enum RecapNotificationPolicy {

    /// Whether this is a moment to ask.
    ///
    /// `alreadyAsked` is checked first and is one-way. iOS shows the system
    /// prompt exactly once per install; asking again silently no-ops, so a second
    /// attempt is not a retry, it is a lie in the code.
    static func shouldAsk(
        hasOpenedRecap: Bool,
        hasCompletedAWeek: Bool,
        alreadyAsked: Bool
    ) -> Bool {
        guard !alreadyAsked else { return false }
        return hasOpenedRecap || hasCompletedAWeek
    }
}

/// The app's one and only notification: a weekly nudge that the recap is ready.
///
/// One request, one identifier, repeating weekly. Nothing else in TapLog
/// schedules anything, and rescheduling replaces this request rather than
/// stacking beside it, so the count of pending TapLog notifications is always
/// zero or one.
@MainActor
final class RecapNotifier: NSObject {

    static let shared = RecapNotifier()

    /// The single request identifier. Reusing it is what makes rescheduling
    /// idempotent — `add` replaces a pending request with the same id.
    static let requestIdentifier = "dev.amteshwar.taplog.recap.weekly"

    /// Posted when the user taps the notification. ContentView listens for this
    /// rather than the notification centre directly, mirroring how
    /// `OpenCaptureIntent` already routes into the app: one way in, one place
    /// that decides what a route means.
    static let openRecapNotification = Notification.Name("dev.amteshwar.taplog.openRecap")

    private static let askedKey = "notifications.recapPermissionAsked"
    private static let openedRecapKey = "notifications.hasOpenedRecap"

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = StoreLocator.sharedDefaults
    ) {
        self.center = center
        self.defaults = defaults
        super.init()
    }

    // MARK: - Content

    /// The notification's words.
    ///
    /// No amount, anywhere. A lock screen is a public surface — it is read over
    /// shoulders, on desks, by whoever picks the phone up — and what someone
    /// spent last week is theirs to look at, not to broadcast. The number lives
    /// one tap away behind Face ID, which is where it belongs.
    static func makeContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Your week is ready."
        content.body = "See where it went."
        content.userInfo = ["route": "recap"]
        return content
    }

    // MARK: - Schedule

    /// Fires on the morning the new week opens — which is the morning the week
    /// the recap covers has just closed.
    ///
    /// The weekday comes from the user's own calendar, so this lands on the same
    /// boundary the recap, the history's "This week", and the streak all use. A
    /// notification that arrived a day off from the week it described would be
    /// its own small lie.
    static func triggerComponents(calendar: Calendar = .current, hour: Int = 9) -> DateComponents {
        var components = DateComponents()
        components.weekday = calendar.firstWeekday
        components.hour = hour
        components.minute = 0
        return components
    }

    /// Replaces any pending recap notification with a fresh weekly one.
    func scheduleWeeklyRecap(calendar: Calendar = .current) {
        let request = UNNotificationRequest(
            identifier: Self.requestIdentifier,
            content: Self.makeContent(),
            trigger: UNCalendarNotificationTrigger(
                dateMatching: Self.triggerComponents(calendar: calendar),
                repeats: true
            )
        )
        center.add(request) { error in
            if let error {
                print("TapLog: Failed to schedule the weekly recap notification — \(error)")
            }
        }
    }

    /// Drops the scheduled notification. Used by the clean-slate wipe: someone
    /// who has just deleted every expense should not be told next Sunday that
    /// their week is ready.
    func cancelWeeklyRecap() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
    }

    // MARK: - Permission

    /// Remembers that the recap has been seen. Recorded when it opens; the ask
    /// itself waits until it closes — see `askIfRelevant`.
    func recordRecapOpened() {
        defaults.set(true, forKey: Self.openedRecapKey)
    }

    /// Asks for permission if — and only if — this is one of the two earned
    /// moments, then schedules on a yes.
    ///
    /// Called as the recap is dismissed rather than while it is on screen: "after
    /// recap first opens" is satisfied either way, and interrupting someone
    /// mid-read with a system sheet spends the one prompt at the worst moment
    /// to spend it.
    func askIfRelevant(hasCompletedAWeek: Bool, calendar: Calendar = .current) {
        guard RecapNotificationPolicy.shouldAsk(
            hasOpenedRecap: defaults.bool(forKey: Self.openedRecapKey),
            hasCompletedAWeek: hasCompletedAWeek,
            alreadyAsked: defaults.bool(forKey: Self.askedKey)
        ) else { return }

        // Written before the prompt returns, not after: iOS shows it once per
        // install whatever we do, so the flag records that the one prompt was
        // spent, not what the answer was.
        defaults.set(true, forKey: Self.askedKey)

        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            if let error {
                print("TapLog: Notification permission request failed — \(error)")
            }
            guard granted else { return }
            Task { @MainActor in
                self?.scheduleWeeklyRecap(calendar: calendar)
            }
        }
    }
}

// MARK: - Taps

extension RecapNotifier: UNUserNotificationCenterDelegate {

    /// These are the completion-handler forms on purpose.
    ///
    /// The `async` forms were tried first and crashed the app the first time
    /// anyone tapped the notification: declaring them `nonisolated async` let the
    /// continuation resume on the cooperative pool, and UIKit finished the
    /// response there — `-[UIApplication _updateSnapshotAndStateRestorationWithAction:]`
    /// asserts off the main thread, SIGABRT, on the single path this whole
    /// feature exists for. The system delivers these callbacks on the main
    /// thread; hopping explicitly makes where the completion handler runs a fact
    /// rather than a hope.

    /// Nothing is shown while the app is open. The recap is already one tap away
    /// on screen; a banner over it would be the app interrupting itself.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let isRecapNotification = response.notification.request.identifier == Self.requestIdentifier
        DispatchQueue.main.async {
            if isRecapNotification {
                NotificationCenter.default.post(name: Self.openRecapNotification, object: nil)
            }
            completionHandler()
        }
    }
}
