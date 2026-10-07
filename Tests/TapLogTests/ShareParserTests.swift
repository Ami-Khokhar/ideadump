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

    // MARK: - The bare-number fallback needs permission

    /// The exact message this gate exists for. The loose pattern used to grab the
    /// first digits in any shared text, so an OTP became a six-figure expense.
    func testOTPMessageProducesNoAmount() {
        XCTAssertNil(ShareParser.parse("Your OTP is 482910").amount)
    }

    func testOtherCodeBearingMessagesProduceNoAmount() {
        XCTAssertNil(ShareParser.parse("482910 is your verification code. Do not share it with anyone.").amount)
        XCTAssertNil(ShareParser.parse("Your delivery arrives between 4 and 6 today").amount)
        XCTAssertNil(ShareParser.parse("Flight AI 2634 is on time, gate 12").amount)
        XCTAssertNil(ShareParser.parse("Meeting moved to 11:30").amount)
    }

    /// The gate must not cost the fallback its actual job: a real payment SMS
    /// that names no currency symbol at all.
    func testSymbolLessPaymentSMSStillParses() {
        XCTAssertEqual(ShareParser.parse("You spent 12.50 at Starbucks").amount, Decimal(string: "12.50"))
        XCTAssertEqual(ShareParser.parse("Amount in Rs: 1,200 at BigBasket").amount, Decimal(string: "1200"))
        XCTAssertEqual(ShareParser.parse("450 debited from your account").amount, Decimal(string: "450"))
        XCTAssertEqual(ShareParser.parse("Paid 89 to Uber").amount, Decimal(string: "89"))
    }

    /// "yours" and "hrs" contain "rs"; a substring check would have let the OTP
    /// straight back through.
    func testSpendingMarkersMatchWholeWordsOnly() {
        XCTAssertFalse(ShareParser.mentionsSpending("Yours truly, 482910"))
        XCTAssertFalse(ShareParser.mentionsSpending("Delayed by 3 hrs"))
        XCTAssertFalse(ShareParser.mentionsSpending("Paytm code 482910"), "a prefix match on \"pay\" would reopen the hole")
        XCTAssertFalse(ShareParser.mentionsSpending("Spencer Plaza opens at 10"))
        XCTAssertFalse(ShareParser.mentionsSpending("Your OTP is 482910"))
        XCTAssertTrue(ShareParser.mentionsSpending("Rs 40 debited"))
        XCTAssertTrue(ShareParser.mentionsSpending("You spent 12.50"))
        XCTAssertTrue(ShareParser.mentionsSpending("₹40"))
    }
}

// MARK: - Bounded share input

extension ShareParserTests {
    func testBoundedTextKeepsOnlyTheFirstAttachments() {
        let pieces = (1...20).map { "piece-\($0)" }
        let text = ShareParser.boundedText(pieces)
        XCTAssertTrue(text.contains("piece-1"))
        XCTAssertTrue(text.contains("piece-\(ShareParser.maxAttachments)"))
        XCTAssertFalse(text.contains("piece-\(ShareParser.maxAttachments + 1)"), "only maxAttachments pieces are considered")
    }

    func testBoundedTextSlicesAnOversizedFieldToTheFieldCap() {
        let huge = String(repeating: "x", count: ShareParser.maxFieldLength * 3)
        XCTAssertEqual(ShareParser.boundedText([huge]).count, ShareParser.maxFieldLength)
    }

    func testBoundedTextCapsTheWholeText() {
        let piece = String(repeating: "y", count: ShareParser.maxFieldLength)
        let text = ShareParser.boundedText(Array(repeating: piece, count: ShareParser.maxAttachments))
        XCTAssertLessThanOrEqual(text.count, ShareParser.maxTextLength)
    }

    func testBoundedTextLeavesAnOrdinaryShareIntact() {
        let pieces = ["Rs 40 debited at BigBasket", "Your OTP is 482910"]
        XCTAssertEqual(ShareParser.boundedText(pieces), "Rs 40 debited at BigBasket Your OTP is 482910")
    }

    func testBoundedTextKeepsPiecesAtTheFieldCap() {
        let first = String(repeating: "a", count: ShareParser.maxFieldLength)
        let second = String(repeating: "b", count: ShareParser.maxFieldLength)
        let text = ShareParser.boundedText([first, second])
        XCTAssertTrue(text.hasPrefix(first), "the first piece is within every cap")
        XCTAssertLessThanOrEqual(text.count, ShareParser.maxTextLength)
        XCTAssertTrue(text.contains(String(repeating: "b", count: 1999)), "the second piece is cut by only the separator")
    }
}

// MARK: - Ambiguous amounts and OTP-plus-payment

extension ShareParserTests {
    func testAnchoredAmountWinsBesideAnOTP() {
        let result = ShareParser.parse("Your OTP is 482910. You spent Rs 12.50 at Starbucks")
        XCTAssertEqual(result.amount, Decimal(string: "12.50"))
    }

    func testSymbolLessPaymentBesideAnOTPIsDeclinedRatherThanGuessed() {
        // Both numbers are bare; the parser cannot tell the code from the
        // payment, so it declines instead of filing the code as an expense.
        XCTAssertNil(ShareParser.parse("Your OTP is 482910. You spent 12.50 at Starbucks").amount)
    }

    func testTheFirstAnchoredAmountWinsWhenABalanceFollows() {
        XCTAssertEqual(ShareParser.parse("Rs 100 debited at BigBasket. Balance Rs 5,000").amount, 100)
    }

    func testMentionsOneTimeCodeRecognizesCommonForms() {
        XCTAssertTrue(ShareParser.mentionsOneTimeCode("Your OTP is 1234"))
        XCTAssertTrue(ShareParser.mentionsOneTimeCode("Use verification code 123456"))
        XCTAssertTrue(ShareParser.mentionsOneTimeCode("Enter your UPI PIN 1234"))
        XCTAssertFalse(ShareParser.mentionsOneTimeCode("Rs 40 debited at BigBasket"))
    }

    func testParseIgnoresTextBeyondTheLengthCap() {
        let filler = String(repeating: "x", count: ShareParser.maxTextLength)
        XCTAssertNil(ShareParser.parse(filler + " Rs 10").amount, "text past the cap is not scanned")
        XCTAssertEqual(ShareParser.parse("Rs 10 " + filler).amount, 10, "an amount inside the cap still parses")
    }

    /// A raw cut can leave a fragment of a number that then parses as a smaller,
    /// plausible amount. The cap must not leave such a fragment: a token that
    /// straddles it keeps its head and loses its trailing digits.
    func testATruncatedShareNeverYieldsAPartialAmount() {
        let text = String(repeating: "x", count: ShareParser.maxTextLength - 7) + " Rs 1,234.56"
        XCTAssertNil(ShareParser.parse(text).amount, "a half-cut amount must not yield a partial amount")
    }

    func testAnAmountBeforeTheCapIsStillFound() {
        let text = "Rs 1,234.56 debited " + String(repeating: "x", count: ShareParser.maxTextLength)
        XCTAssertEqual(ShareParser.parse(text).amount, Decimal(string: "1234.56"))
    }
}

// MARK: - The per-piece cut the share extension applies

extension ShareParserTests {
    func testABoundedPieceKeepsAnAmountInsideTheFieldCap() {
        let piece = "Rs 1,234.56 debited " + String(repeating: "x", count: ShareParser.maxFieldLength)
        XCTAssertEqual(
            ShareParser.parse(ShareParser.boundedPiece(piece)).amount,
            Decimal(string: "1234.56")
        )
    }

    func testABoundedPieceDoesNotCutANumberInHalf() {
        let piece = String(repeating: "x", count: ShareParser.maxFieldLength - 7) + " Rs 1,234.56"
        XCTAssertNil(
            ShareParser.parse(ShareParser.boundedPiece(piece)).amount,
            "a piece cut before the parser must not yield a partial amount"
        )
    }
}

// MARK: - The cut keeps complete tokens and keywords

extension ShareParserTests {
    func testACutOnWhitespaceKeepsTheLastCompleteToken() {
        let amount = " Rs 100"
        let text = String(repeating: "a", count: 96) + amount + " tail"
        let bounded = ShareParser.cutAtTokenBoundary(text, limit: 96 + amount.count)
        XCTAssertTrue(bounded.hasSuffix(amount), "a complete token at the boundary must not be dropped")
    }

    func testCappingAPieceKeepsTheHeadOfTheTokenItCuts() {
        // The cut lands inside "Zzkeyword" (a token nothing else repeats), whose
        // head must survive so the words around it are not lost with it.
        let piece = "Rs 100 " + "Zzkeyword" + String(repeating: "x", count: ShareParser.maxFieldLength)
        let bounded = ShareParser.boundedPiece(piece)
        XCTAssertTrue(bounded.contains("Zzkeyword"), "the token the cut lands in must keep its head")
        XCTAssertEqual(ShareParser.parse(bounded).amount, 100, "the amount before the cut is still found")
    }
}

// MARK: - A cut beside a code marker

extension ShareParserTests {
    func testACutBesideAnOTPMarkerStillDeclinesTheCode() {
        // "OTP." keeps its word boundary after the cap strips the tail, so the
        // marker is still seen (the round-one cut dropped the whole token).
        let piece = "You spent 482910 OTP." + String(repeating: "x", count: ShareParser.maxFieldLength)
        XCTAssertNil(
            ShareParser.parse(ShareParser.boundedPiece(piece)).amount,
            "the OTP marker beside the cut must survive"
        )
    }
}
