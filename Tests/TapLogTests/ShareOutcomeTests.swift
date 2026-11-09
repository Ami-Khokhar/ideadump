import XCTest
@testable import TapLog

/// The share extension cannot be unit tested, so the only thing that can hold
/// its failure messages is this value. The regression it guards: both failures
/// used to produce one sentence, which is why the #65 report could not be
/// diagnosed from the screen.
final class ShareOutcomeTests: XCTestCase {
    /// .../Tests/TapLogTests/ShareOutcomeTests.swift -> the repository root.
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// The extension has no test target, so the call site is asserted against
    /// its source, the way `PaywallReasonTests` asserts the Settings sheet.
    /// Without this, the value could exist and the extension could keep its own
    /// ternary, which is the state the gate rejected.
    /// The production call passes `item.attributedContentText`, which is
    /// `NSAttributedString?`. Swift boxes that as `Any` holding an optional, and
    /// the cast has to unwrap it or the body is ignored again — the original
    /// #65 bug, arriving silently as empty text.
    func testAnOptionalAttributedBodyIsReadThroughTheBoxedOptional() {
        let body: NSAttributedString? = NSAttributedString(string: "Rs 250 debited")
        XCTAssertEqual(
            ShareParser.nonemptyText(from: body),
            "Rs 250 debited",
            "the optional body the extension actually passes must survive the Any? cast"
        )
        let absent: NSAttributedString? = nil
        XCTAssertNil(
            ShareParser.nonemptyText(from: absent),
            "an absent body must stay absent rather than become an empty string"
        )
    }

    func testTheExtensionShowsTheSharedOutcome() throws {
        let extensionSource = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/TapLogShare/ShareViewController.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            extensionSource.contains("ShareOutcome.of(parsed)"),
            "the share extension must ask ShareOutcome which sentence to show"
        )
        XCTAssertFalse(
            extensionSource.contains("Shared text had no amount TapLog could read"),
            "the sentence belongs to ShareOutcome, not to the extension"
        )
        XCTAssertFalse(
            extensionSource.contains("parsed.amount"),
            "the amount travels inside ShareOutcome.saved, so the extension must not unwrap the parse again"
        )
    }

    func testAnEmptyShareSaysNothingWasShared() {
        XCTAssertEqual(ShareOutcome.of(ShareParse(amount: nil, note: nil, hasText: false)), .nothingShared)
    }

    func testTextWithoutAnAmountSaysTheAmountWasNotReadable() {
        XCTAssertEqual(
            ShareOutcome.of(ShareParse(amount: nil, note: nil, hasText: true)),
            .noReadableAmount
        )
    }

    func testAZeroAmountIsTreatedAsUnreadable() {
        XCTAssertEqual(
            ShareOutcome.of(ShareParse(amount: 0, note: nil, hasText: true)),
            .noReadableAmount,
            "a zero amount is not an expense, and the message must not claim one was saved"
        )
    }

    func testAParsedAmountIsCarriedInTheSavedOutcome() {
        XCTAssertEqual(
            ShareOutcome.of(ShareParse(amount: 12.5, note: "Cafe", hasText: true)),
            .saved(12.5),
            "an entry that was read is saved, not explained"
        )
    }

    func testTheTwoFailuresDoNotShareOneSentence() throws {
        XCTAssertNotEqual(
            ShareOutcome.nothingShared.message,
            ShareOutcome.noReadableAmount.message,
            "an empty share and an unparseable one must be told apart on screen"
        )
        XCTAssertTrue(try XCTUnwrap(ShareOutcome.nothingShared.message).contains("Nothing was shared"))
        XCTAssertTrue(try XCTUnwrap(ShareOutcome.noReadableAmount.message).contains("no amount"))
    }
}
