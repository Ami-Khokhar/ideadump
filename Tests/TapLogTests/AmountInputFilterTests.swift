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

    // MARK: - Pasted Grouped Amounts (must NOT be corrupted)

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

    /// The keypad let a second decimal point through, so 15.5.2.275.57 could be
    /// typed one key at a time: the guard below only caught a *different*
    /// separator arriving second, never a repeat of the same one.
    func testTypingSecondDecimalSeparatorRestoresPreviousValue() {
        let result = AmountInputFilter.filterEdit(
            current: "15.5",
            range: NSRange(location: 4, length: 0),
            replacement: ".",
            decimalSeparator: "."
        )
        XCTAssertTrue(result.restoresPrevious)
        XCTAssertEqual(result.text, "15.5")
    }

    func testRepeatedDecimalSeparatorsNeverAccumulate() {
        var current = ""
        for key in ["1", "5", ".", "5", ".", "2", ".", "2", "7", "5", ".", "5", "7"] {
            let result = AmountInputFilter.filterEdit(
                current: current,
                range: NSRange(location: (current as NSString).length, length: 0),
                replacement: key,
                decimalSeparator: "."
            )
            if !result.restoresPrevious { current = result.text }
        }
        XCTAssertEqual(current, "15.52", "only one decimal point, capped at two fractional digits")
    }

    /// Grouping is not the decimal mark, so it may legitimately repeat —
    /// 1,20,000 is typed one comma at a time in an en_IN locale.
    func testRepeatedGroupingSeparatorIsStillAccepted() {
        let result = AmountInputFilter.filterEdit(
            current: "1,20",
            range: NSRange(location: 4, length: 0),
            replacement: ",",
            decimalSeparator: "."
        )
        XCTAssertFalse(result.restoresPrevious)
        XCTAssertEqual(result.text, "1,20,")
    }

    /// In a comma-decimal locale the roles swap: the dot groups and may repeat,
    /// the comma is the decimal point and may not.
    func testDecimalSeparatorRuleFollowsTheLocaleNotTheGlyph() {
        let repeatedComma = AmountInputFilter.filterEdit(
            current: "12,5",
            range: NSRange(location: 4, length: 0),
            replacement: ",",
            decimalSeparator: ","
        )
        XCTAssertTrue(repeatedComma.restoresPrevious)

        let repeatedDot = AmountInputFilter.filterEdit(
            current: "1.200",
            range: NSRange(location: 5, length: 0),
            replacement: ".",
            decimalSeparator: ","
        )
        XCTAssertFalse(repeatedDot.restoresPrevious)
        XCTAssertEqual(repeatedDot.text, "1.200.")
    }

    // MARK: - Leading Zeros

    func testTypingDigitAfterLoneZeroReplacesIt() {
        let result = AmountInputFilter.filterEdit(
            current: "0", range: NSRange(location: 1, length: 0), replacement: "2"
        )
        XCTAssertEqual(result.text, "2")
        XCTAssertNil(result.error)
    }

    func testLeadingZerosNeverAccumulate() {
        var current = ""
        for key in ["0", "2", "5"] {
            let result = AmountInputFilter.filterEdit(
                current: current,
                range: NSRange(location: (current as NSString).length, length: 0),
                replacement: key
            )
            if !result.restoresPrevious { current = result.text }
        }
        XCTAssertEqual(current, "25")
    }

    func testLoneZeroSurvivesSoDecimalsCanBeTyped() {
        let zero = AmountInputFilter.filterEdit(
            current: "", range: NSRange(location: 0, length: 0), replacement: "0"
        )
        XCTAssertEqual(zero.text, "0")

        let separator = AmountInputFilter.filterEdit(
            current: "0", range: NSRange(location: 1, length: 0), replacement: ".", decimalSeparator: "."
        )
        XCTAssertEqual(separator.text, "0.")

        let fraction = AmountInputFilter.filterEdit(
            current: "0.", range: NSRange(location: 2, length: 0), replacement: "5"
        )
        XCTAssertEqual(fraction.text, "0.5")
        XCTAssertEqual(Money.parse(fraction.text), Decimal(string: "0.5"))
    }

    func testInteriorAndFractionalZerosAreUntouched() {
        XCTAssertEqual(AmountInputFilter.strippingLeadingZeros("100"), "100")
        XCTAssertEqual(AmountInputFilter.strippingLeadingZeros("10.05"), "10.05")
        XCTAssertEqual(AmountInputFilter.strippingLeadingZeros("0.50"), "0.50")
        XCTAssertEqual(AmountInputFilter.strippingLeadingZeros("00"), "0")
        XCTAssertEqual(AmountInputFilter.strippingLeadingZeros("007"), "7")
        XCTAssertEqual(AmountInputFilter.strippingLeadingZeros("0,50"), "0,50")
    }

    func testTypingZeroAfterANonZeroDigitStillAppends() {
        let result = AmountInputFilter.filterEdit(
            current: "1", range: NSRange(location: 1, length: 0), replacement: "0"
        )
        XCTAssertEqual(result.text, "10")
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
