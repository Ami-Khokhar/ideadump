import XCTest
@testable import TapLog

/// Coverage for the shared SMS parser — the share extension's only brain.
final class ShareParserTests: XCTestCase {

    // MARK: - Amount extraction

    func testExtractsDollarAmount() {
        XCTAssertEqual(ShareParser.parse("CHASE: You spent $12.50 at Starbucks").amount, Decimal(string: "12.50"))
    }

    func testExtractsRupeeSymbolAmount() {
        XCTAssertEqual(ShareParser.parse("₹99 only for snacks").amount, 99)
    }

    func testExtractsIndianRsPrefixAmount() {
        // The most common Indian bank-SMS format; must find 500, not a fragment.
        XCTAssertEqual(ShareParser.parse("Rs 500 paid to Uber").amount, 500)
        XCTAssertEqual(ShareParser.parse("rs.250 debited").amount, Decimal(string: "250"))
    }

    func testExtractsINRAmountBeforeAccountDigits() {
        // INR must win over account/card/date digits earlier in a bank message.
        let result = ShareParser.parse("Your A/c XX1234 is debited by INR 500 at Swiggy")
        XCTAssertEqual(result.amount, 500)
    }

    func testHandlesGroupedIndianNumbering() {
        // "1,234.50" must be one amount, not the fragment "234.50".
        XCTAssertEqual(ShareParser.parse("Rs.1,234.50 debited HDFC").amount, Decimal(string: "1234.50"))
        XCTAssertEqual(ShareParser.parse("$1,200.50 at Amazon").amount, Decimal(string: "1200.50"))
    }

    func testFallsBackToPlainNumber() {
        XCTAssertEqual(ShareParser.parse("payment of 45 thanks").amount, 45)
    }

    func testPlainFallbackKeepsGroupedAmountsIntact() {
        // The bare-number fallback must not match just the first digit run.
        XCTAssertEqual(ShareParser.parse("Paid 1,200 at Amazon").amount, 1200)
    }

    func testEmptyAndJunkInputYieldNoAmount() {
        XCTAssertNil(ShareParser.parse("").amount)
        XCTAssertNil(ShareParser.parse("no numbers here").amount)
        // Pasted phone numbers exceed maxAmount and must not become expenses.
        XCTAssertNil(ShareParser.parse("missed call 9876543210123456789").amount)
    }

    func testAbsurdPrefixedAmountDoesNotDegradeToFragment() {
        // "$1,000,000,000" is over the cap — parsing must yield nil, not fall
        // through to the looser pattern and log the leading "1" as $1.
        XCTAssertNil(ShareParser.parse("spent $1,000,000,000 at Amazon").amount)
        XCTAssertNil(ShareParser.parse("Rs 9,999,999,999 debited").amount)
    }

    // MARK: - Note extraction

    func testNoteKeepsMerchantDropsStopwords() {
        let result = ShareParser.parse("CHASE: You spent $12.50 at Starbucks")
        XCTAssertTrue(result.note?.contains("Starbucks") ?? false)
        XCTAssertFalse(result.note?.lowercased().contains("spent") ?? true)
    }

    func testNoteDropsBankNoiseAndDigits() {
        let result = ShareParser.parse("HDFC Bank: Rs 1,200 debited on card xx1234 at BigBasket")
        XCTAssertTrue(result.note?.contains("BigBasket") ?? false)
        XCTAssertFalse(result.note?.contains("1200") ?? true)
        XCTAssertFalse(result.note?.lowercased().contains("debited") ?? true)
    }

    func testJunkInputYieldsNoNote() {
        XCTAssertNil(ShareParser.parse("").note)
        XCTAssertNil(ShareParser.parse("12345").note)
    }
}
