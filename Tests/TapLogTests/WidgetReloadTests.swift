import XCTest
@testable import TapLog

/// The two new reload requests (a currency change and a foregrounding) spend
/// WidgetKit's per-widget budget, which is the thing the midnight entry depends
/// on. These pin the gate that keeps a plain activation from spending it.
final class WidgetReloadTests: XCTestCase {
    private let suiteName = "test.WidgetReload"
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

    private func seed(logCount: Int = 4, currencyCode: String = "INR") {
        defaults.set(logCount, forKey: "logsLogged")
        defaults.set(currencyCode, forKey: "currencyCode")
    }

    private var currentInputs: WidgetReload.Inputs {
        WidgetReload.currentInputs(defaults: defaults)
    }

    func testCurrentInputsReadTheSharedValues() {
        seed(logCount: 7, currencyCode: "EUR")

        XCTAssertEqual(
            currentInputs,
            WidgetReload.Inputs(logCount: 7, currencyCode: "EUR")
        )
    }

    func testFirstRequestIsAlwaysWorthMaking() {
        seed()

        XCTAssertTrue(WidgetReload.shouldRequest(currentInputs, defaults: defaults))
    }

    func testASecondActivationWithNothingChangedAsksForNothing() {
        seed()
        XCTAssertTrue(WidgetReload.shouldRequest(currentInputs, defaults: defaults))

        XCTAssertFalse(
            WidgetReload.shouldRequest(currentInputs, defaults: defaults),
            "foregrounding again is not news, and the midnight entry needs that budget"
        )
    }

    func testALogRecordedElsewhereMakesTheNextActivationAsk() {
        seed(logCount: 4)
        XCTAssertTrue(WidgetReload.shouldRequest(currentInputs, defaults: defaults))

        // A widget quick-log landed while the app was in the background.
        defaults.set(5, forKey: "logsLogged")

        XCTAssertTrue(WidgetReload.shouldRequest(currentInputs, defaults: defaults))
        XCTAssertFalse(WidgetReload.shouldRequest(currentInputs, defaults: defaults))
    }

    func testACurrencyChangeAsksImmediately() {
        seed(currencyCode: "INR")
        XCTAssertTrue(WidgetReload.shouldRequest(currentInputs, defaults: defaults))

        defaults.set("EUR", forKey: "currencyCode")

        XCTAssertTrue(WidgetReload.shouldRequest(currentInputs, defaults: defaults))
        XCTAssertFalse(
            WidgetReload.shouldRequest(currentInputs, defaults: defaults),
            "one change costs one request"
        )
    }

    func testReturningToAnEarlierStateIsAChangeAgain() {
        seed(logCount: 4, currencyCode: "INR")
        XCTAssertTrue(WidgetReload.shouldRequest(currentInputs, defaults: defaults))

        defaults.set(5, forKey: "logsLogged")
        XCTAssertTrue(WidgetReload.shouldRequest(currentInputs, defaults: defaults))

        // An undo takes the counter back; the widget has to follow it.
        defaults.set(4, forKey: "logsLogged")
        XCTAssertTrue(WidgetReload.shouldRequest(currentInputs, defaults: defaults))
    }
}
