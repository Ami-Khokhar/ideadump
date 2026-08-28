import XCTest
import UserNotifications
@testable import TapLog

/// The rules around the app's only notification: when it may ask, when it fires,
/// and what it is allowed to say.
final class RecapNotifierTests: XCTestCase {

    // MARK: - When we may ask

    func testNeverAsksBeforeEitherMomentHasHappened() {
        // This is the launch case, and the one that matters most: nothing has
        // happened yet, so nothing has earned the one prompt iOS will ever show.
        XCTAssertFalse(
            RecapNotificationPolicy.shouldAsk(
                hasOpenedRecap: false,
                hasCompletedAWeek: false,
                alreadyAsked: false
            )
        )
    }

    func testAsksAfterTheRecapHasBeenSeen() {
        XCTAssertTrue(
            RecapNotificationPolicy.shouldAsk(
                hasOpenedRecap: true,
                hasCompletedAWeek: false,
                alreadyAsked: false
            )
        )
    }

    func testAsksAfterAWeekHasBeenCompleted() {
        XCTAssertTrue(
            RecapNotificationPolicy.shouldAsk(
                hasOpenedRecap: false,
                hasCompletedAWeek: true,
                alreadyAsked: false
            )
        )
    }

    func testNeverAsksTwice() {
        // iOS shows the system prompt once per install. A second attempt is not a
        // retry — it silently does nothing — so the code must not pretend it is.
        for opened in [true, false] {
            for completed in [true, false] {
                XCTAssertFalse(
                    RecapNotificationPolicy.shouldAsk(
                        hasOpenedRecap: opened,
                        hasCompletedAWeek: completed,
                        alreadyAsked: true
                    ),
                    "opened: \(opened), completed: \(completed)"
                )
            }
        }
    }

    // MARK: - When it fires

    /// The notification has to land on the same week boundary as the recap it
    /// announces. A Sunday-first user getting it on Monday would be told their
    /// week was ready a day into the next one.
    @MainActor
    func testFiresOnTheFirstDayOfTheUsersOwnWeek() {
        var sundayFirst = Calendar(identifier: .gregorian)
        sundayFirst.firstWeekday = 1
        var mondayFirst = Calendar(identifier: .gregorian)
        mondayFirst.firstWeekday = 2

        XCTAssertEqual(RecapNotifier.triggerComponents(calendar: sundayFirst).weekday, 1)
        XCTAssertEqual(RecapNotifier.triggerComponents(calendar: mondayFirst).weekday, 2)
    }

    @MainActor
    func testFiresInTheMorning() {
        let components = RecapNotifier.triggerComponents(calendar: .current)
        XCTAssertEqual(components.hour, 9)
        XCTAssertEqual(components.minute, 0)
        XCTAssertNil(components.day, "pinning a day would make this fire once a month, not once a week")
        XCTAssertNil(components.month)
    }

    // MARK: - What it says

    /// A lock screen is a public surface. What someone spent is theirs to look
    /// at, not to broadcast to whoever is standing next to them.
    @MainActor
    func testTheNotificationNamesNoAmounts() {
        let content = RecapNotifier.makeContent()
        let text = content.title + " " + content.body

        XCTAssertFalse(
            text.contains(where: \.isNumber),
            "no digits: \(text)"
        )
        for symbol in ["₹", "$", "€", "£", "¥"] {
            XCTAssertFalse(text.contains(symbol), "no currency symbol: \(text)")
        }
        XCTAssertFalse(text.isEmpty)
    }

    @MainActor
    func testTheNotificationPointsAtTheRecap() {
        XCTAssertEqual(RecapNotifier.makeContent().userInfo["route"] as? String, "recap")
    }

    /// One identifier, reused. `UNUserNotificationCenter.add` replaces a pending
    /// request with the same id, which is the whole mechanism preventing a user
    /// from accumulating a second, third and fourth weekly nudge.
    @MainActor
    func testTheRequestIdentifierIsStable() {
        XCTAssertEqual(RecapNotifier.requestIdentifier, "dev.amteshwar.taplog.recap.weekly")
    }
}
