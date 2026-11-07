import XCTest
@testable import TapLog

/// The Lock Screen widgets' routing and copy are asserted as data —
/// `AccessoryWidgetRoute` — so a future edit that points an accessory at a link
/// the app cannot resolve, or back at a `Link`, fails a test instead of shipping
/// a tap that goes nowhere or a label VoiceOver never reads.
final class AccessoryWidgetRouteTests: XCTestCase {

    func testEveryAccessoryRouteIsAcceptedByCapturePrefill() {
        for route in AccessoryWidgetRoute.allCases {
            XCTAssertNotNil(
                CapturePrefill(url: route.url),
                "\(route) must open a link CapturePrefill accepts, or a Lock Screen tap does nothing"
            )
        }
    }

    func testEveryAccessoryLabelMatchesTheVisiblePrompt() {
        for route in AccessoryWidgetRoute.allCases {
            XCTAssertEqual(
                route.label,
                "Log expense",
                "\(route) must announce the same words the rectangular widget shows"
            )
        }
    }

    /// Accessory widgets route through the widget-level URL. A `Link` inside one
    /// could render clipped or fail to route, which is the bug #61 fixed and #70
    /// left untested.
    func testAccessoryBranchesDoNotUseLink() throws {
        let accessory = try accessoryRegion()
        XCTAssertFalse(
            accessory.contains("Link("),
            "accessory widgets must use widgetURL, not Link"
        )
    }

    /// One capture route, one owner. The widget used to spell `taplog://log` out
    /// at five sites, each free to drift.
    func testTheWidgetBuildsNoCaptureURLOwnItsOwn() throws {
        let source = try String(contentsOf: widgetSourceURL, encoding: .utf8)
        XCTAssertFalse(
            source.contains(#"URL(string: "taplog://log")"#),
            "the capture route must come from AccessoryWidgetRoute.captureURL"
        )
    }

    // MARK: - Reading the widget source

    private var widgetSourceURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/TapLogWidget/SpendWidget.swift")
    }

    /// The switch branches WidgetKit asks for on the Lock Screen. Between the
    /// first accessory case and the fallback, every line is accessory layout.
    private func accessoryRegion() throws -> String {
        let source = try String(contentsOf: widgetSourceURL, encoding: .utf8)
        guard let start = source.range(of: "case .accessoryCircular:"),
              let end = source.range(of: "default:", range: start.upperBound..<source.endIndex) else {
            XCTFail("SpendWidget must still have an accessory layout before its default branch")
            return ""
        }
        return String(source[start.lowerBound..<end.lowerBound])
    }
}
