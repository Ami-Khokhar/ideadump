import XCTest
@testable import TapLog

/// Pins the first-render opening decision for the capture screen. The durable
/// pending flag is read before `ContentView` builds its body, so a widget or
/// Siri activation never starts the plant at all (issue #60).
final class OpeningActionTests: XCTestCase {
    func testPendingActivationOnFirstRenderSkipsTheOpening() {
        let action = LogHomeView.openingAction(
            hasPendingActivation: true,
            reduceMotion: false,
            isOnboarding: false
        )
        XCTAssertEqual(action, .skipOnMount)
    }

    func testOrdinaryLaunchRunsTheOpening() {
        let action = LogHomeView.openingAction(
            hasPendingActivation: false,
            reduceMotion: false,
            isOnboarding: false
        )
        XCTAssertEqual(action, .run)
    }

    func testPendingActivationOutranksReduceMotion() {
        let action = LogHomeView.openingAction(
            hasPendingActivation: true,
            reduceMotion: true,
            isOnboarding: false
        )
        XCTAssertEqual(action, .skipOnMount)
    }

    func testReduceMotionRevealsImmediately() {
        let action = LogHomeView.openingAction(
            hasPendingActivation: false,
            reduceMotion: true,
            isOnboarding: false
        )
        XCTAssertEqual(action, .skipImmediately)
    }

    func testOnboardingStepRevealsImmediately() {
        let action = LogHomeView.openingAction(
            hasPendingActivation: false,
            reduceMotion: false,
            isOnboarding: true
        )
        XCTAssertEqual(action, .skipImmediately)
    }
}
