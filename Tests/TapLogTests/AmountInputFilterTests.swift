import XCTest
@testable import TapLog

/// Regression tests for `AmountInputFilter`:
/// - Typed input: two-decimal enforcement, valid characters only
/// - Pasted input: preserves separators consistent with Money.parse
/// - Grouped currency values are never corrupted
/// - Oversized values show inline error, are not silently accepted
/// - Font sizing never produces a size below the minimum
final class AmountInputFilterTests: XCTestCase {

    func testSelectionRestoresAfterRejectedEdit() {
        let original = NSRange(location: 1, length: 2)
        let result = AmountEditResult(text: "12.50", error: nil, restoresPrevious: true)

        XCTAssertEqual(
            AmountTextField.Coordinator.selectionAfterEdit(
                current: "12.50",
                originalSelection: original,
                editRange: NSRange(location: 1, length: 0),
                replacement: "9",
                result: result
            ),
            original
        )
    }

    func testSelectionMovesAfterAcceptedReplacementAndIsBounded() {
        let result = AmountEditResult(text: "19.50", error: nil, restoresPrevious: false)

        XCTAssertEqual(
            AmountTextField.Coordinator.selectionAfterEdit(
                current: "12.50",
                originalSelection: NSRange(location: 0, length: 0),
                editRange: NSRange(location: 1, length: 1),
                replacement: "9",
                result: result
            ),
            NSRange(location: 2, length: 0)
        )
    }

    func testSelectionMapsPastCurrencySymbolThatFilterStrips() {
        let current = "12.50"
        let editRange = NSRange(location: 2, length: 0)
        let replacement = "$"
        let result = AmountInputFilter.filterEdit(
            current: current,
            range: editRange,
            replacement: replacement
        )

        XCTAssertEqual(result.text, "12.50")
        XCTAssertEqual(
            AmountTextField.Coordinator.selectionAfterEdit(
                current: current,
                originalSelection: editRange,
                editRange: editRange,
                replacement: replacement,
                result: result
            ),
            NSRange(location: 2, length: 0)
        )
    }

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

    // MARK: - Edit metadata (selection replacement)

    func testSelectionReplacementUSGroupingUsesReplacementValue() {
        let result = AmountInputFilter.filterEdit(
            current: "12,34", range: NSRange(location: 0, length: 5), replacement: "1,200"
        )
        XCTAssertEqual(result.text, "1,200")
        XCTAssertNil(result.error)
        XCTAssertEqual(Money.parse(result.text), 1200)
    }

    func testSelectionReplacementEuropeanGroupingUsesReplacementValue() {
        let result = AmountInputFilter.filterEdit(
            current: "12.34", range: NSRange(location: 0, length: 5), replacement: "1.200,50"
        )
        XCTAssertEqual(result.text, "1.200,50")
        XCTAssertNil(result.error)
        XCTAssertEqual(Money.parse(result.text), Decimal(string: "1200.50"))
    }

    func testSelectionReplacementWithCurrencySymbolPreservesAmount() {
        let result = AmountInputFilter.filterEdit(
            current: "9999", range: NSRange(location: 0, length: 4), replacement: "$1,200"
        )
        XCTAssertEqual(result.text, "1,200")
        XCTAssertNil(result.error)
        XCTAssertEqual(Money.parse(result.text), 1200)
    }

    func testTypingMixedSeparatorRestoresPreviousValue() {
        let result = AmountInputFilter.filterEdit(
            current: "1.2", range: NSRange(location: 3, length: 0), replacement: ","
        )
        XCTAssertTrue(result.restoresPrevious)
        XCTAssertEqual(result.text, "1.2")
        XCTAssertNotNil(result.error)
    }

    func testTypingDotDecimalOneEditAtATime() {
        let first = AmountInputFilter.filterEdit(
            current: "12", range: NSRange(location: 2, length: 0), replacement: "."
        )
        XCTAssertEqual(first.text, "12.")
        XCTAssertNil(first.error)

        let second = AmountInputFilter.filterEdit(
            current: first.text, range: NSRange(location: 3, length: 0), replacement: "3"
        )
        XCTAssertEqual(second.text, "12.3")
        XCTAssertNil(second.error)

        let third = AmountInputFilter.filterEdit(
            current: second.text, range: NSRange(location: 4, length: 0), replacement: "4"
        )
        XCTAssertEqual(third.text, "12.34")
        XCTAssertNil(third.error)
    }

    func testTypingCommaDecimalOneEditAtATime() {
        let first = AmountInputFilter.filterEdit(
            current: "12", range: NSRange(location: 2, length: 0), replacement: ","
        )
        XCTAssertEqual(first.text, "12,")
        XCTAssertNil(first.error)

        let second = AmountInputFilter.filterEdit(
            current: first.text, range: NSRange(location: 3, length: 0), replacement: "3"
        )
        XCTAssertEqual(second.text, "12,3")
        XCTAssertNil(second.error)

        let third = AmountInputFilter.filterEdit(
            current: second.text, range: NSRange(location: 4, length: 0), replacement: "4"
        )
        XCTAssertEqual(third.text, "12,34")
        XCTAssertNil(third.error)
    }

    func testContinuousDigitTypingUsesNativeApplicationDecision() {
        var current = ""

        for digit in ["1", "2", "3", "4", "5"] {
            let range = NSRange(location: current.utf16.count, length: 0)
            let result = AmountInputFilter.filterEdit(
                current: current,
                range: range,
                replacement: digit
            )

            XCTAssertTrue(
                AmountTextField.Coordinator.shouldApplyEditNatively(
                    current: current,
                    editRange: range,
                    replacement: digit,
                    result: result
                ),
                "digit \(digit) should be applied natively for stable keyboard input"
            )

            current = (current as NSString).replacingCharacters(in: range, with: digit)
            XCTAssertEqual(current, result.text)
        }
    }

    func testRejectedTypedDigitDoesNotUseNativeApplicationDecision() {
        let result = AmountInputFilter.filterEdit(
            current: "12.34",
            range: NSRange(location: 5, length: 0),
            replacement: "5"
        )

        XCTAssertFalse(
            AmountTextField.Coordinator.shouldApplyEditNatively(
                current: "12.34",
                editRange: NSRange(location: 5, length: 0),
                replacement: "5",
                result: result
            )
        )
    }

    func testDeletingFractionalDigitKeepsNativeEditingActive() {
        let range = NSRange(location: 3, length: 1)
        let result = AmountInputFilter.filterEdit(
            current: "12.3",
            range: range,
            replacement: ""
        )

        XCTAssertEqual(result.text, "12.")
        XCTAssertNil(result.error)
        XCTAssertTrue(
            AmountTextField.Coordinator.shouldApplyEditNatively(
                current: "12.3",
                editRange: range,
                replacement: "",
                result: result
            )
        )
    }

    func testOversizedSelectionReplacementRemainsVisible() {
        let result = AmountInputFilter.filterEdit(
            current: "999999999", range: NSRange(location: 0, length: 9), replacement: "1000000000"
        )
        XCTAssertFalse(result.restoresPrevious)
        XCTAssertEqual(result.text, "1000000000")
        XCTAssertTrue(result.error?.contains("Maximum") == true)
    }

    func testOversizedPasteCanBeCorrectedOrDeleted() {
        let oversized = AmountInputFilter.filterEdit(
            current: "", range: NSRange(location: 0, length: 0), replacement: "1000000000"
        )
        XCTAssertEqual(oversized.text, "1000000000")
        XCTAssertNotNil(oversized.error)

        let corrected = AmountInputFilter.filterEdit(
            current: oversized.text,
            range: NSRange(location: 0, length: oversized.text.count),
            replacement: "999999999"
        )
        XCTAssertEqual(corrected.text, "999999999")
        XCTAssertNil(corrected.error)

        let deleted = AmountInputFilter.filterEdit(
            current: oversized.text,
            range: NSRange(location: oversized.text.count - 1, length: 1),
            replacement: ""
        )
        XCTAssertEqual(deleted.text, "100000000")
        XCTAssertNil(deleted.error)
    }

    func testTypedDigitOverMaximumRestoresPreviousValue() {
        let result = AmountInputFilter.filterEdit(
            current: "999999999",
            range: NSRange(location: 9, length: 0),
            replacement: "0"
        )
        XCTAssertTrue(result.restoresPrevious)
        XCTAssertEqual(result.text, "999999999")
    }

    func testTypedThirdFractionalDigitRestoresPreviousValue() {
        let result = AmountInputFilter.filterEdit(
            current: "12.34",
            range: NSRange(location: 5, length: 0),
            replacement: "5"
        )
        XCTAssertTrue(result.restoresPrevious)
        XCTAssertEqual(result.text, "12.34")
    }

    func testMalformedMixedSeparatorReplacementRemainsVisible() {
        let result = AmountInputFilter.filterEdit(
            current: "12", range: NSRange(location: 0, length: 2), replacement: "1.2,"
        )
        XCTAssertEqual(result.text, "1.2,")
        XCTAssertEqual(result.error, "Invalid amount format.")
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
