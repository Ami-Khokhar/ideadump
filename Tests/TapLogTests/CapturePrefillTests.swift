import XCTest
@testable import TapLog

/// Deep links (`taplog://log?amount=…`) pre-fill the capture form.
final class CapturePrefillTests: XCTestCase {

    func testParsesAllParameters() {
        let url = URL(string: "taplog://log?amount=12.50&note=coffee&category=Coffee")!
        let prefill = CapturePrefill(url: url)
        XCTAssertNotNil(prefill)
        XCTAssertEqual(prefill?.amountText, "12.50")
        XCTAssertEqual(prefill?.note, "coffee")
        XCTAssertEqual(prefill?.categoryQuery, "Coffee")
    }

    func testPercentEncodedValuesDecode() {
        let url = URL(string: "taplog://log?amount=5&note=chai%20time&category=Tea%20%26%20Biscuits")!
        let prefill = CapturePrefill(url: url)
        XCTAssertEqual(prefill?.note, "chai time")
        XCTAssertEqual(prefill?.categoryQuery, "Tea & Biscuits")
    }

    func testRejectsForeignSchemesAndHosts() {
        XCTAssertNil(CapturePrefill(url: URL(string: "https://log?amount=1")!))
        XCTAssertNil(CapturePrefill(url: URL(string: "otherapp://log?amount=1")!))
        XCTAssertNil(CapturePrefill(url: URL(string: "taplog://settings")!))
    }

    func testMissingParametersAreNilNotFatal() {
        let prefill = CapturePrefill(url: URL(string: "taplog://log")!)
        XCTAssertNotNil(prefill)
        XCTAssertNil(prefill?.amountText)
        XCTAssertNil(prefill?.note)
        XCTAssertNil(prefill?.categoryQuery)
    }

    func testPartialParametersPassThrough() {
        let prefill = CapturePrefill(url: URL(string: "taplog://log?amount=7")!)
        XCTAssertEqual(prefill?.amountText, "7")
        XCTAssertNil(prefill?.note)
        XCTAssertNil(prefill?.categoryQuery)
    }
}
