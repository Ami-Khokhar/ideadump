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

    /// The regression this PR exists to remove: the label sat on a `ZStack`
    /// wrapping the image, where SwiftUI applies it only if that container is
    /// made an element, so VoiceOver read the bare SF Symbol. Putting the
    /// wrapper back fails this test; the data-only assertions above stay green.
    func testTheCircularAccessoryLabelsTheImageItself() throws {
        let circular = try accessoryCase(
            from: "case .accessoryCircular:",
            to: "case .accessoryRectangular:"
        )
        XCTAssertTrue(
            circular.contains(".accessibilityLabel("),
            "the circular accessory must keep an accessibility label"
        )
        XCTAssertFalse(
            circular.contains("ZStack {"),
            "a ZStack around the image drops the label VoiceOver speaks"
        )
    }

    /// A label on a container with two children is ignored unless the container
    /// is made one element. Dropping that line makes VoiceOver announce "Add"
    /// and then "Log expense" as two elements.
    func testTheRectangularAccessoryCombinesItsChildrenBeforeLabelling() throws {
        let rectangular = try accessoryCase(
            from: "case .accessoryRectangular:",
            to: "default:"
        )
        XCTAssertTrue(
            rectangular.contains(".accessibilityElement(children: .ignore)"),
            "the rectangular accessory must be one element or the label is ignored"
        )
        XCTAssertTrue(
            rectangular.contains(".accessibilityLabel("),
            "the rectangular accessory must keep an accessibility label"
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

    /// One `case` branch of the accessory layout, so a modifier can be asserted
    /// against the family that needs it. Read from the whole file: the region
    /// helper stops before the layout's `default:` branch, so the last case in
    /// it has no end marker inside that region.
    private func accessoryCase(from startMarker: String, to endMarker: String) throws -> String {
        let source = try String(contentsOf: widgetSourceURL, encoding: .utf8)
        guard let start = source.range(of: startMarker),
              let end = source.range(of: endMarker, range: start.upperBound..<source.endIndex) else {
            XCTFail("SpendWidget must still have a \(startMarker) branch")
            return ""
        }
        return String(source[start.lowerBound..<end.lowerBound])
    }
}
