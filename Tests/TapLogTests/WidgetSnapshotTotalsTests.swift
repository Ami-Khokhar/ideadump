import XCTest
@testable import TapLog

/// The mapping that turns one widget store read into rendered figures. A failure
/// must surface as the unavailable state, never as a valid-looking zero.
final class WidgetSnapshotTotalsTests: XCTestCase {

    func testAThrowingReaderYieldsAnUnavailableSnapshot() {
        struct ForcedFailure: Error {}

        let totals = WidgetSnapshotTotals.map { throw ForcedFailure() }

        XCTAssertFalse(totals.isAvailable)
        XCTAssertEqual(totals.total, 0)
        XCTAssertEqual(totals.count, 0)
    }

    func testASuccessfulReaderYieldsAnAvailableSnapshot() {
        let totals = WidgetSnapshotTotals.map {
            [
                Entry(amount: 12, category: "chai"),
                Entry(amount: 30, category: "chai"),
            ]
        }

        XCTAssertTrue(totals.isAvailable)
        XCTAssertEqual(totals.total, 42)
        XCTAssertEqual(totals.count, 2)
    }

    func testAnEmptyDayIsAvailableRatherThanUnavailable() {
        let totals = WidgetSnapshotTotals.map { [] }

        XCTAssertTrue(totals.isAvailable)
        XCTAssertEqual(totals.total, 0)
        XCTAssertEqual(totals.count, 0)
    }
}
