import XCTest
@testable import TapLog

/// Regression coverage for the two money bugs:
///  1. `parse` silently turned a US "1,200" into 1.20 (1000× error).
///  2. `fromAmount` (Siri/widget path) imported binary-float artifacts from `Double`.
final class MoneyTests: XCTestCase {

    // MARK: - parse: plain and decimal

    func testParsesPlainIntegerAndDecimal() {
        XCTAssertEqual(Money.parse("12"), 12)
        XCTAssertEqual(Money.parse("12.50"), Decimal(string: "12.50"))
        XCTAssertEqual(Money.parse("12.5"), Decimal(string: "12.5"))
        XCTAssertEqual(Money.parse("0.99"), Decimal(string: "0.99"))
        XCTAssertEqual(Money.parse(".50"), Decimal(string: "0.50"))
    }

    func testParsesEuropeanCommaDecimal() {
        XCTAssertEqual(Money.parse("12,50"), Decimal(string: "12.50"))
        XCTAssertEqual(Money.parse("1,2"), Decimal(string: "1.2"))
    }

    // MARK: - parse: the 1000× regression

    func testUSThousandsSeparatorIsNotTreatedAsDecimal() {
        // The original bug: "1,200" -> 1.20. Must be 1200.
        XCTAssertEqual(Money.parse("1,200"), 1200)
        XCTAssertEqual(Money.parse("1,200,000"), 1_200_000)
    }

    func testMixedGroupingAndDecimalSeparators() {
        // US style: comma groups, dot is decimal.
        XCTAssertEqual(Money.parse("1,200.50"), Decimal(string: "1200.50"))
        // European style: dot groups, comma is decimal.
        XCTAssertEqual(Money.parse("1.200,50"), Decimal(string: "1200.50"))
        XCTAssertEqual(Money.parse("1.234.567,89"), Decimal(string: "1234567.89"))
    }

    func testDotGroupingWithoutDecimal() {
        // European grouping with no decimal part: "1.200" means 1200.
        XCTAssertEqual(Money.parse("1.200"), 1200)
        XCTAssertEqual(Money.parse("1.234.567"), 1_234_567)
    }

    // MARK: - parse: currency symbols and whitespace

    func testStripsCurrencySymbolsAndSpaces() {
        XCTAssertEqual(Money.parse("$12"), 12)
        XCTAssertEqual(Money.parse("$1,200.50"), Decimal(string: "1200.50"))
        XCTAssertEqual(Money.parse("€12,50"), Decimal(string: "12.50"))
        XCTAssertEqual(Money.parse("£ 12.50"), Decimal(string: "12.50"))
        XCTAssertEqual(Money.parse("  12.50  "), Decimal(string: "12.50"))
    }

    // MARK: - parse: rejects garbage

    func testRejectsAbsurdAmounts() {
        // Pasted junk (phone numbers, etc.) must never become corrupted expenses.
        XCTAssertNil(Money.parse("7887883774877847847"))
        XCTAssertNil(Money.parse("12345678901234567890"))
        XCTAssertNil(Money.parse("$1,000,000,000"))
        XCTAssertEqual(Money.parse("999,999,999.99"), Decimal(string: "999999999.99"))
        XCTAssertNil(Money.parse("1,000,000,000"))
    }

    func testRejectsNonNumericInput() {
        XCTAssertNil(Money.parse(""))
        XCTAssertNil(Money.parse("   "))
        XCTAssertNil(Money.parse("abc"))
        XCTAssertNil(Money.parse("$"))
    }

    // MARK: - fromAmount: Double -> Decimal precision

    func testFromAmountRoundsToCentsWithoutFloatArtifacts() {
        // Decimal(12.99) alone is 12.99000000000000199...; fromAmount must give 12.99.
        XCTAssertEqual(Money.fromAmount(12.99), Decimal(string: "12.99"))
        XCTAssertEqual(Money.fromAmount(0.1), Decimal(string: "0.10"))
        XCTAssertEqual(Money.fromAmount(0.3), Decimal(string: "0.30"))
        XCTAssertEqual(Money.fromAmount(4.5), Decimal(string: "4.50"))
        XCTAssertEqual(Money.fromAmount(12), Decimal(string: "12"))
    }

    func testFromAmountRoundsAtCents() {
        // Third decimal rounds off at cents.
        XCTAssertEqual(Money.fromAmount(2.346), Decimal(string: "2.35"))
        XCTAssertEqual(Money.fromAmount(2.344), Decimal(string: "2.34"))
    }

    // MARK: - plainString round-trips back through parse

    func testPlainStringRoundTrips() {
        for value in ["12.5", "1200", "0.99", "1234567.89"] {
            let decimal = Decimal(string: value)!
            let roundTripped = Money.parse(Money.plainString(decimal))
            XCTAssertEqual(roundTripped, decimal, "round trip failed for \(value)")
        }
    }
}
