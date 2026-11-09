import XCTest
@testable import TapLog

/// Holds the widget's home-screen capture taps to the rule that decided issue
/// #84: a tap runs `OpenCaptureIntent` in the widget's own process, so the
/// durable pending activation is written before the app makes its opening-
/// animation decision. A tap that opened `taplog://log` instead would arrive at
/// `onOpenURL` after the first capture view renders and flash part of the plant.
///
/// These tests read `SpendWidget.swift` for the same reason
/// `AccessoryWidgetRouteTests` does: the routing lives in SwiftUI view code that
/// the app's test target cannot compile, and asserting the enum alone would stay
/// green with every tap reverted to a `Link`.
final class WidgetCaptureTapTests: XCTestCase {
    private var widgetSource: String {
        get throws {
            try String(
                contentsOf: repoRoot.appendingPathComponent("Sources/TapLogWidget/SpendWidget.swift"),
                encoding: .utf8
            )
        }
    }

    // MARK: - The tap rule

    func testEveryNamedTapAppearsInTheWidget() throws {
        let source = try widgetSource
        for tap in WidgetCaptureTap.allCases {
            XCTAssertTrue(
                source.contains(tap.callSite),
                "\(tap.rawValue) is named in WidgetCaptureTap, so the widget must call \(tap.callSite)"
            )
        }
    }

    /// A fourth tap added to the widget without a name here would otherwise slip
    /// past every assertion above.
    func testTheWidgetOffersNoUnnamedCaptureTap() throws {
        let source = try widgetSource
        let named = Set(WidgetCaptureTap.allCases.map(\.callSite))
        let offered = matches(in: source, pattern: #"captureButton\(\.([A-Za-z]+)\)"#)
            .map { "captureButton(.\($0))" }
        XCTAssertFalse(offered.isEmpty, "the widget must offer at least one capture tap")
        XCTAssertEqual(
            Set(offered), named,
            "every captureButton(.<case>) in the widget must be a WidgetCaptureTap case"
        )
    }

    func testTheCaptureButtonRunsTheIntentAndNeverALink() throws {
        let source = try widgetSource
        let body = try region(
            in: source,
            from: "private func captureButton(",
            to: "private func quickLogButton("
        )
        XCTAssertTrue(
            body.contains("Button(intent: OpenCaptureIntent())"),
            "a home-screen capture tap must run the intent so the pending flag exists before launch"
        )
        XCTAssertFalse(
            body.contains("Link("),
            "a Link would reach the app through onOpenURL, after the first capture render"
        )
    }

    // MARK: - The home-screen regions

    func testTheSmallWidgetOpensNoURL() throws {
        let small = try region(in: try widgetSource, from: "private var smallView:", to: "private var mediumView:")
        XCTAssertFalse(small.contains("Link("), "the small widget must not open a URL")
        XCTAssertFalse(small.contains(".widgetURL("), "the small widget tap must not be a URL")
    }

    func testTheMediumWidgetOpensNoURL() throws {
        let medium = try region(in: try widgetSource, from: "private var mediumContent:", to: "private func captureButton(")
        XCTAssertFalse(medium.contains("Link("), "the medium widget must not open a URL")
        XCTAssertFalse(medium.contains(".widgetURL("), "the medium widget taps must not be URLs")
    }

    // MARK: - The intent the widget compiles

    func testTheAppKeepsTheDiscoverableIntent() {
        // This test runs in the app target, where OpenCaptureIntent is the
        // discoverable copy that Shortcuts lists. The widget compiles the same
        // intent with isDiscoverable false so the action is not listed twice.
        XCTAssertTrue(OpenCaptureIntent.openAppWhenRun)
        XCTAssertTrue(OpenCaptureIntent.isDiscoverable)
    }

    // MARK: - Reading the widget source

    /// .../Tests/TapLogTests/WidgetCaptureTapTests.swift -> the repository root.
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func region(in source: String, from start: String, to end: String) throws -> String {
        guard let startRange = source.range(of: start) else {
            throw RegionError.missingStart(start)
        }
        guard let endRange = source.range(of: end, range: startRange.upperBound..<source.endIndex) else {
            throw RegionError.missingEnd(end)
        }
        return String(source[startRange.lowerBound..<endRange.lowerBound])
    }

    private func matches(in source: String, pattern: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return regex.matches(in: source, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let captured = Range(match.range(at: 1), in: source) else { return nil }
            return String(source[captured])
        }
    }

    private enum RegionError: Error {
        case missingStart(String)
        case missingEnd(String)
    }
}
