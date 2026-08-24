import XCTest
@testable import TapLog

/// Regression tests for `AmountInputFilter`:
/// - Typed input: two-decimal enforcement, valid characters only
/// - Pasted input: preserves separators consistent with Money.parse
/// - Grouped currency values are never corrupted
/// - Oversized values show inline error, are not silently accepted
/// - Font sizing never produces a size below the minimum
final class AmountInputFilterTests: XCTestCase {

    // MARK: - Typed Input

    func testEmptyInputIsAccepted() {
        let result = AmountInputFilter.filter("", current: "")
        switch result {
        case .accepted(let text): XCTAssertEqual(text, "")
        case .rejected: XCTFail("empty input should be accepted")
        }
    }

    func testPlainIntegerIsAccepted() {
        let result = AmountInputFilter.filter("120", current: "12")
        switch result {
        case .accepted(let text): XCTAssertEqual(text, "120")
        case .rejected: XCTFail("plain integer should be accepted")
        }
    }

    func testDecimalInputIsAccepted() {
        let result = AmountInputFilter.filter("12.50", current: "12.5")
        switch result {
        case .accepted(let text): XCTAssertEqual(text, "12.50")
        case .rejected: XCTFail("decimal input should be accepted")
        }
    }

    func testThirdDecimalDigitIsDropped() {
        let result = AmountInputFilter.filter("12.503", current: "12.50")
        switch result {
        case .accepted(let text):
            XCTAssertEqual(text, "12.50", "third decimal digit should be dropped")
        case .rejected:
            XCTFail("should accept but drop the third decimal")
        }
    }

    func testTwoDecimalsIsAccepted() {
        let result = AmountInputFilter.filter("99.99", current: "99.9")
        switch result {
        case .accepted(let text): XCTAssertEqual(text, "99.99")
        case .rejected: XCTFail("two decimals should be accepted")
        }
    }

    func testEuropeanCommaDecimalIsAccepted() {
        let result = AmountInputFilter.filter("12,50", current: "12,5")
        switch result {
        case .accepted(let text): XCTAssertEqual(text, "12,50")
        case .rejected: XCTFail("European comma decimal should be accepted")
        }
    }

    // MARK: - Pasted Grouped Amounts (must NOT be corrupted)

    func testPasteUSGroupingPreservesValue() {
        // "$1,200" pasted into empty field — should preserve "1200" or "1,200".
        let result = AmountInputFilter.filter("$1,200", current: "")
        switch result {
        case .accepted(let text):
            // The paste path runs Money.parse on the stripped text.
            XCTAssertEqual(Money.parse(text), 1200,
                           "pasted $1,200 must parse as 1200, not 1.20")
        case .rejected(let error):
            XCTFail("pasted $1,200 should be accepted, got error: \(error)")
        }
    }

    func testPasteUSGroupingWithDecimal() {
        let result = AmountInputFilter.filter("1,200.50", current: "")
        switch result {
        case .accepted(let text):
            XCTAssertEqual(Money.parse(text), Decimal(string: "1200.50"),
                           "pasted 1,200.50 must parse as 1200.50")
        case .rejected(let error):
            XCTFail("should be accepted, got: \(error)")
        }
    }

    func testPasteEuropeanGrouping() {
        let result = AmountInputFilter.filter("1.200,50", current: "")
        switch result {
        case .accepted(let text):
            XCTAssertEqual(Money.parse(text), Decimal(string: "1200.50"),
                           "pasted 1.200,50 must parse as 1200.50")
        case .rejected(let error):
            XCTFail("should be accepted, got: \(error)")
        }
    }

    func testPasteIndianGrouping() {
        // Indian: 1,20,000 = 120000
        let result = AmountInputFilter.filter("1,20,000", current: "")
        switch result {
        case .accepted(let text):
            XCTAssertEqual(Money.parse(text), 120000,
                           "pasted 1,20,000 must parse as 120000")
        case .rejected(let error):
            XCTFail("should be accepted, got: \(error)")
        }
    }

    func testPasteSimpleCommaDecimal() {
        let result = AmountInputFilter.filter("12,50", current: "")
        switch result {
        case .accepted(let text):
            XCTAssertEqual(Money.parse(text), Decimal(string: "12.50"),
                           "pasted 12,50 must parse as 12.50")
        case .rejected(let error):
            XCTFail("should be accepted, got: \(error)")
        }
    }

    func testPasteCurrencySymbolStripped() {
        let result = AmountInputFilter.filter("$12.50", current: "")
        switch result {
        case .accepted(let text):
            XCTAssertEqual(Money.parse(text), Decimal(string: "12.50"))
        case .rejected(let error):
            XCTFail("should be accepted, got: \(error)")
        }
    }

    // MARK: - Maximum Amount

    func testExactMaxAmountIsAccepted() {
        let result = AmountInputFilter.filter("999999999.99", current: "999999999.9")
        switch result {
        case .accepted(let text): XCTAssertEqual(text, "999999999.99")
        case .rejected: XCTFail("exact max amount should be accepted")
        }
    }

    func testAboveMaxAmountIsRejected() {
        let result = AmountInputFilter.filter("1000000000", current: "999999999")
        // Must be rejected — not accepted with either outcome.
        switch result {
        case .accepted:
            XCTFail("1000000000 must be rejected, not accepted")
        case .rejected(let error):
            XCTAssertTrue(error.contains("Maximum"), "error should mention maximum")
        }
    }

    func testPasteAboveMaxIsRejected() {
        let result = AmountInputFilter.filter("1000000000.00", current: "")
        switch result {
        case .accepted:
            XCTFail("oversized paste must be rejected")
        case .rejected(let error):
            XCTAssertTrue(error.contains("Maximum"))
        }
    }

    func testErrorMessageForOversizedValue() {
        let error = AmountInputFilter.errorMessage(for: "1000000000")
        XCTAssertNotNil(error, "oversized value should produce an error")
        XCTAssertTrue(error!.contains("Maximum"), "error should mention maximum")
    }

    func testErrorMessageIsNilForValidValue() {
        XCTAssertNil(AmountInputFilter.errorMessage(for: "12.50"))
        XCTAssertNil(AmountInputFilter.errorMessage(for: ""))
        XCTAssertNil(AmountInputFilter.errorMessage(for: "0"))
    }

    // MARK: - Pasted Long Strings

    func testVeryLongPasteIsRejected() {
        let longPaste = String(repeating: "9", count: 20)
        let result = AmountInputFilter.filter(longPaste, current: "")
        switch result {
        case .rejected(let error):
            XCTAssertNotNil(error, "very long paste should produce an error")
        case .accepted:
            XCTFail("paste exceeding maxDisplayLength should be rejected")
        }
    }

    // MARK: - isValid / parsedAmount

    func testIsValidForZeroAndEmpty() {
        XCTAssertFalse(AmountInputFilter.isValid(""))
        XCTAssertFalse(AmountInputFilter.isValid("0"))
        XCTAssertFalse(AmountInputFilter.isValid("0.00"))
    }

    func testIsValidForPositiveAmount() {
        XCTAssertTrue(AmountInputFilter.isValid("12.50"))
        XCTAssertTrue(AmountInputFilter.isValid("1"))
        XCTAssertTrue(AmountInputFilter.isValid("999999999.99"))
    }

    func testIsValidRejectsOverMax() {
        XCTAssertFalse(AmountInputFilter.isValid("1000000000"))
    }

    func testParsedAmountReturnsNilForInvalid() {
        XCTAssertNil(AmountInputFilter.parsedAmount(""))
        XCTAssertNil(AmountInputFilter.parsedAmount("0"))
        XCTAssertNil(AmountInputFilter.parsedAmount("abc"))
    }

    func testParsedAmountReturnsDecimalForValid() {
        XCTAssertEqual(AmountInputFilter.parsedAmount("12.50"), Decimal(string: "12.50"))
        XCTAssertEqual(AmountInputFilter.parsedAmount("999999999.99"), Decimal(string: "999999999.99"))
    }

    // MARK: - AmountFont Sizing

    func testShortAmountUsesBaseFontSize() {
        XCTAssertEqual(AmountFont.fontSize(for: ""), AmountFont.baseFontSize)
        XCTAssertEqual(AmountFont.fontSize(for: "12"), AmountFont.baseFontSize)
        XCTAssertEqual(AmountFont.fontSize(for: "123456"), AmountFont.baseFontSize)
    }

    func testMediumAmountShrinksGradually() {
        let size7 = AmountFont.fontSize(for: "1234567")
        let size8 = AmountFont.fontSize(for: "12345678")
        let size9 = AmountFont.fontSize(for: "123456789")
        XCTAssertLessThan(size7, AmountFont.baseFontSize, "7 chars should shrink below base")
        XCTAssertLessThan(size8, size7, "8 chars should be smaller than 7")
        XCTAssertLessThan(size9, size8, "9 chars should be smaller than 8")
    }

    func testLongAmountNeverShrinksBelowMinimum() {
        let size13 = AmountFont.fontSize(for: "1234567890123")
        let size20 = AmountFont.fontSize(for: String(repeating: "1", count: 20))
        XCTAssertGreaterThanOrEqual(size13, AmountFont.minFontSize)
        XCTAssertGreaterThanOrEqual(size20, AmountFont.minFontSize)
    }

    func testFontDecreasesMonotonically() {
        var previous = AmountFont.baseFontSize
        for count in 1...20 {
            let text = String(repeating: "1", count: count)
            let size = AmountFont.fontSize(for: text)
            XCTAssertLessThanOrEqual(size, previous, "font should not increase at \(count) chars")
            previous = size
        }
    }
}
