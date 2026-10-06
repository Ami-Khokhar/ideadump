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

// MARK: - Bounded fields and URL shape

extension CapturePrefillTests {
    func testBoundsNoteAndCategoryLengths() {
        let note = String(repeating: "n", count: 500)
        let category = String(repeating: "c", count: 200)
        let url = URL(string: "taplog://log?note=\(note)&category=\(category)")!
        let prefill = CapturePrefill(url: url)
        XCTAssertEqual(prefill?.note?.count, CapturePrefill.maxNoteLength)
        XCTAssertEqual(prefill?.categoryQuery?.count, CapturePrefill.maxCategoryLength)
    }

    func testShortFieldsAreLeftAlone() {
        let prefill = CapturePrefill(url: URL(string: "taplog://log?note=coffee&category=Tea")!)
        XCTAssertEqual(prefill?.note, "coffee")
        XCTAssertEqual(prefill?.categoryQuery, "Tea")
    }

    func testDuplicateKeysUseTheFirstValue() {
        let prefill = CapturePrefill(url: URL(string: "taplog://log?amount=5&amount=99&note=first&note=second")!)
        XCTAssertEqual(prefill?.amountText, "5")
        XCTAssertEqual(prefill?.note, "first")
    }

    func testRejectsUnexpectedUrlComponents() {
        XCTAssertNil(CapturePrefill(url: URL(string: "taplog://log:8080?amount=1")!))
        XCTAssertNil(CapturePrefill(url: URL(string: "taplog://user@log?amount=1")!))
        XCTAssertNil(CapturePrefill(url: URL(string: "taplog://log/extra?amount=1")!))
        XCTAssertNil(CapturePrefill(url: URL(string: "taplog://log?amount=1#frag")!))
    }

    func testAcceptsAnEmptyOrSlashPath() {
        XCTAssertNotNil(CapturePrefill(url: URL(string: "taplog://log?amount=1")!))
        XCTAssertNotNil(CapturePrefill(url: URL(string: "taplog://log/?amount=1")!))
    }

    func testSchemeAndHostCaseAreAccepted() {
        XCTAssertNotNil(CapturePrefill(url: URL(string: "TAPLOG://LOG?amount=1")!))
    }

    func testUnknownKeysAreIgnored() {
        let prefill = CapturePrefill(url: URL(string: "taplog://log?amount=5&save=yes&category=Tea")!)
        XCTAssertEqual(prefill?.amountText, "5")
        XCTAssertEqual(prefill?.categoryQuery, "Tea")
    }

    func testAParameterWithoutAValueIsIgnored() {
        let prefill = CapturePrefill(url: URL(string: "taplog://log?amount=5&note")!)
        XCTAssertEqual(prefill?.amountText, "5")
        XCTAssertNil(prefill?.note)
    }

    func testAWhitespaceOnlyFieldIsNil() {
        let prefill = CapturePrefill(url: URL(string: "taplog://log?note=%20%20")!)
        XCTAssertNil(prefill?.note)
    }
}

// MARK: - Boundary and malformed-encoding cases

extension CapturePrefillTests {
    func testAValueAtTheCapIsNotTruncated() {
        let note = String(repeating: "n", count: CapturePrefill.maxNoteLength)
        let category = String(repeating: "c", count: CapturePrefill.maxCategoryLength)
        let url = URL(string: "taplog://log?note=\(note)&category=\(category)")!
        let prefill = CapturePrefill(url: url)
        XCTAssertEqual(prefill?.note, note, "a value exactly at the cap must survive intact")
        XCTAssertEqual(prefill?.categoryQuery, category)
    }

    func testMalformedPercentEncodingLeavesThatFieldNil() {
        var components = URLComponents()
        components.scheme = "taplog"
        components.host = "log"
        components.percentEncodedQuery = "amount=1&note=%E0%A4"
        let prefill = CapturePrefill(url: components.url!)
        XCTAssertEqual(prefill?.amountText, "1")
        XCTAssertNil(prefill?.note, "an undecodable value prefills nothing")
    }
}
