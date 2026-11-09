import XCTest
@testable import TapLog

/// Coverage for the share extension's collection policy: which shared pieces
/// reach the parser, and in what order. The extension only loads
/// `NSItemProvider`; the decisions live here so they can be tested.
final class ShareTextCollectorTests: XCTestCase {

    // MARK: - Body versus attachments

    func testABodyThatCarriesAnAmountSuppressesItsAttachments() {
        let item = ShareTextCollector.Item(
            body: "You spent ₹250 at BigBasket",
            attachmentIDs: [0, 1]
        )
        let places = ShareTextCollector.places(for: [item])
        XCTAssertEqual(places, [.body("You spent ₹250 at BigBasket")])
        XCTAssertEqual(
            ShareTextCollector.pieces(from: places, loaded: [0: "Your OTP is 482910", 1: 42]),
            ["You spent ₹250 at BigBasket"]
        )
    }

    func testAnEmptyBodyFallsBackToAttachments() {
        let item = ShareTextCollector.Item(body: nil, attachmentIDs: [0])
        let places = ShareTextCollector.places(for: [item])
        XCTAssertEqual(places, [.attachment(id: 0)])
        XCTAssertEqual(
            ShareTextCollector.pieces(from: places, loaded: [0: Data("Rs 500 debited at Uber".utf8)]),
            ["Rs 500 debited at Uber"]
        )
    }

    /// The risk the review named: a rich link's body is a summary (a title), so
    /// the payment SMS in the attachment must still be read.
    func testABodyWithoutAnAmountFallsBackToItsAttachments() {
        let body = "Paid via UPI — BigBasket"
        let item = ShareTextCollector.Item(body: body, attachmentIDs: [0])
        let places = ShareTextCollector.places(for: [item])
        XCTAssertEqual(places, [.body(body), .attachment(id: 0)])

        let text = ShareParser.boundedText(
            ShareTextCollector.pieces(from: places, loaded: [0: "Rs 1,200 debited. Ref 8871"])
        )
        XCTAssertEqual(ShareParser.parse(text).amount, 1200, "the attachment's amount is still found")
    }

    /// The other order: the body carries the amount and the attachment does not
    /// repeat it, so the body alone must be enough.
    func testABodyThatCarriesTheAmountNeedsNoAttachment() {
        let body = "Rs 250 debited at BigBasket"
        let places = ShareTextCollector.places(
            for: [ShareTextCollector.Item(body: body, attachmentIDs: [0])]
        )
        XCTAssertEqual(places, [.body(body)])
        let text = ShareParser.boundedText(ShareTextCollector.pieces(from: places, loaded: [:]))
        XCTAssertEqual(ShareParser.parse(text).amount, 250)
    }

    // MARK: - Callback order

    func testResultsArrivingOutOfOrderKeepSourceOrder() {
        let items = [
            ShareTextCollector.Item(body: nil, attachmentIDs: [0]),
            ShareTextCollector.Item(body: nil, attachmentIDs: [1]),
        ]
        let places = ShareTextCollector.places(for: items)
        XCTAssertEqual(places, [.attachment(id: 0), .attachment(id: 1)])

        // The second provider finished first; its payload is still second.
        let loaded: [Int: Any] = [1: "second piece", 0: "first piece"]
        XCTAssertEqual(
            ShareTextCollector.pieces(from: places, loaded: loaded),
            ["first piece", "second piece"]
        )
    }

    // MARK: - Unreadable payloads

    func testUnsupportedAndMalformedPayloadsContributeNothing() {
        let item = ShareTextCollector.Item(body: nil, attachmentIDs: [0, 1, 2])
        let places = ShareTextCollector.places(for: [item])
        let loaded: [Int: Any] = [
            0: 42,                      // not a text payload
            1: Data([0xFF]),            // invalid UTF-8
            2: "   \n",                 // whitespace only
        ]
        XCTAssertEqual(ShareTextCollector.pieces(from: places, loaded: loaded), [])
    }

    func testAnAttachmentThatNeverDeliveredContributesNothing() {
        let item = ShareTextCollector.Item(body: nil, attachmentIDs: [0, 1])
        let places = ShareTextCollector.places(for: [item])
        XCTAssertEqual(
            ShareTextCollector.pieces(from: places, loaded: [1: "Rs 40 debited"]),
            ["Rs 40 debited"]
        )
    }

    // MARK: - The cap

    func testMoreAttachmentsThanTheCapAreTruncated() {
        let ids = Array(0..<(ShareParser.maxAttachments + 4))
        let item = ShareTextCollector.Item(body: nil, attachmentIDs: ids)
        let places = ShareTextCollector.places(for: [item])
        XCTAssertEqual(places.count, ShareParser.maxAttachments)
        XCTAssertEqual(places.last, .attachment(id: ShareParser.maxAttachments - 1))
    }

    func testTheCapCountsBodiesAndAttachmentsAcrossItems() {
        let items = [1, 2, 3, 4].map { number in
            ShareTextCollector.Item(
                body: "piece \(number)",
                attachmentIDs: [number * 10]
            )
        }
        let places = ShareTextCollector.places(for: items)
        XCTAssertEqual(places.count, ShareParser.maxAttachments)
    }

    // MARK: - A second item is still read

    func testALaterItemContributesAfterAnEarlierOne() {
        let items = [
            ShareTextCollector.Item(body: "Rs 40 debited", attachmentIDs: []),
            ShareTextCollector.Item(body: nil, attachmentIDs: [0]),
        ]
        let places = ShareTextCollector.places(for: items)
        XCTAssertEqual(places, [.body("Rs 40 debited"), .attachment(id: 0)])
    }
}
