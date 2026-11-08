import XCTest
@testable import TapLog

/// The share extension cannot be unit tested, so the only thing that can hold
/// its failure messages is this value. The regression it guards: both failures
/// used to produce one sentence, which is why the #65 report could not be
/// diagnosed from the screen.
final class ShareOutcomeTests: XCTestCase {

    func testAnEmptyShareSaysNothingWasShared() {
        XCTAssertEqual(ShareOutcome.of(ShareParse(amount: nil, note: nil, hasText: false)), .nothingShared)
    }

    func testTextWithoutAnAmountSaysTheAmountWasNotReadable() {
        XCTAssertEqual(
            ShareOutcome.of(ShareParse(amount: nil, note: nil, hasText: true)),
            .noReadableAmount
        )
    }

    func testAParsedAmountHasNoFailureMessage() {
        XCTAssertNil(
            ShareOutcome.of(ShareParse(amount: 12.5, note: "Cafe", hasText: true)),
            "an entry that was read is saved, not explained"
        )
    }

    func testTheTwoFailuresDoNotShareOneSentence() {
        XCTAssertNotEqual(
            ShareOutcome.nothingShared.message,
            ShareOutcome.noReadableAmount.message,
            "an empty share and an unparseable one must be told apart on screen"
        )
        XCTAssertTrue(ShareOutcome.nothingShared.message.contains("Nothing was shared"))
        XCTAssertTrue(ShareOutcome.noReadableAmount.message.contains("no amount"))
    }
}
