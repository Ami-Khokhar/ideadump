import XCTest
@testable import TapLog

/// Pins the rule that decided issue #84: a home-screen widget capture tap runs
/// the intent in the widget's own process, so the durable pending activation is
/// written before the app makes its opening-animation decision. A tap that opened
/// a URL instead would reach `onOpenURL` after the first capture view appears and
/// flash part of the opening plant.
final class WidgetCaptureTapTests: XCTestCase {
    private var homeScreenTaps: [WidgetCaptureTap] {
        WidgetCaptureTap.allCases.filter { $0 != .accessory }
    }

    func testEveryHomeScreenTapRecordsItsActivationBeforeLaunch() {
        XCTAssertFalse(homeScreenTaps.isEmpty)
        for tap in homeScreenTaps {
            XCTAssertTrue(
                tap.recordsActivationBeforeLaunch,
                "\(tap.rawValue) must run the intent, not open a URL"
            )
            XCTAssertNil(
                tap.url,
                "\(tap.rawValue) must not carry a URL: onOpenURL can arrive after the first render"
            )
        }
    }

    func testTheAccessoryTapKeepsTheCaptureURL() {
        XCTAssertFalse(WidgetCaptureTap.accessory.recordsActivationBeforeLaunch)
        XCTAssertEqual(
            WidgetCaptureTap.accessory.url,
            AccessoryWidgetRoute.captureURL
        )
    }

    func testEveryTapTheWidgetOffersIsClassified() {
        // Named rather than counted so a new tap site has to be classified here
        // before it ships, and a site cannot be deleted from the widget without
        // deleting it from this list too.
        XCTAssertEqual(
            Set(WidgetCaptureTap.allCases.map(\.rawValue)),
            ["smallFooter", "mediumCustomAmount", "mediumUnavailable", "accessory"]
        )
    }

    func testTheIntentOpensTheAppWithoutBeingListedTwice() {
        // The app target's copy is the discoverable one; the widget compiles the
        // same intent with the flag set, and this test runs in the app target.
        XCTAssertTrue(OpenCaptureIntent.openAppWhenRun)
        XCTAssertTrue(OpenCaptureIntent.isDiscoverable)
    }
}
