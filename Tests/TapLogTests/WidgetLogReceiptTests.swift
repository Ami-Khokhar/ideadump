import XCTest
@testable import TapLog

/// A widget tap is the one capture path with no screen left to show a toast on.
/// These pin the note it leaves for the app.
final class WidgetLogReceiptTests: XCTestCase {
    private let suiteName = "test.WidgetLogReceipt"
    private var defaults: UserDefaults!
    private let noon = Date(timeIntervalSinceReferenceDate: 800_000_000)

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func write(at date: Date, amount: Decimal = 45, category: String = "chai") {
        WidgetLogReceipt.write(
            WidgetLogReceipt(createdAt: date, amount: amount, categoryKey: category),
            defaults: defaults
        )
    }

    func testRoundTripsTheLogItDescribes() {
        write(at: noon, amount: Decimal(string: "123.45")!, category: "rent")

        let receipt = WidgetLogReceipt.consume(now: noon.addingTimeInterval(30), defaults: defaults)

        XCTAssertEqual(receipt?.createdAt, noon, "the timestamp is how the app finds the row again")
        XCTAssertEqual(receipt?.amount, Decimal(string: "123.45"), "money must survive as Decimal, not Double")
        XCTAssertEqual(receipt?.categoryKey, "rent")
    }

    func testNothingPendingReturnsNil() {
        XCTAssertNil(WidgetLogReceipt.consume(now: noon, defaults: defaults))
    }

    func testOneTapCanOnlyProduceOneToast() {
        write(at: noon)

        XCTAssertNotNil(WidgetLogReceipt.consume(now: noon.addingTimeInterval(5), defaults: defaults))
        XCTAssertNil(
            WidgetLogReceipt.consume(now: noon.addingTimeInterval(6), defaults: defaults),
            "consuming clears the slot, so reopening the app does not re-offer the undo"
        )
    }

    func testStaleLogIsNoLongerNews() {
        write(at: noon)
        let tomorrowMorning = noon.addingTimeInterval(WidgetLogReceipt.window + 1)

        XCTAssertNil(WidgetLogReceipt.consume(now: tomorrowMorning, defaults: defaults))
        // Still cleared, so it cannot surface later either.
        XCTAssertNil(WidgetLogReceipt.consume(now: noon.addingTimeInterval(1), defaults: defaults))
    }

    func testLogFromTheFutureIsDiscarded() {
        // The clock moved backwards between the widget's write and the app's read.
        write(at: noon.addingTimeInterval(60))
        XCTAssertNil(WidgetLogReceipt.consume(now: noon, defaults: defaults))
    }

    func testOnlyTheNewestTapIsKept() {
        write(at: noon, amount: 10, category: "chai")
        write(at: noon.addingTimeInterval(2), amount: 80, category: "food")

        let receipt = WidgetLogReceipt.consume(now: noon.addingTimeInterval(3), defaults: defaults)

        XCTAssertEqual(receipt?.amount, 80, "three quick taps are one piece of news")
        XCTAssertEqual(receipt?.categoryKey, "food")
    }
}
