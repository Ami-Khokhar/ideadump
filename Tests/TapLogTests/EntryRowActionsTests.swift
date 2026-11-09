import XCTest
import SwiftUI
@testable import TapLog

/// Issue #58: a History row must show edit and delete, and a full swipe must not
/// run archive/restore by itself. These assertions fail if either visible
/// control is dropped or `allowsFullSwipe` becomes true again.
final class EntryRowActionsTests: XCTestCase {
    /// .../Tests/TapLogTests/EntryRowActionsTests.swift -> the repository root.
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// The behaviour #58 is about lives in a `View`, which the test target
    /// cannot tap, so the wiring is asserted against the list's source the way
    /// `PaywallReasonTests` asserts the Settings sheet. Deleting the visible
    /// controls, or passing a literal `true` to the full swipe, fails here.
    func testTheRowRendersBothControlsAndASlowSwipe() throws {
        let list = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/TapLog/List/EntryListView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            list.contains("rowControls(entry, actions: actions)"),
            "History must draw the visible edit and delete controls; a swipe is not discoverable on its own"
        )
        XCTAssertTrue(
            list.contains("allowsFullSwipe: actions.allowsFullSwipe"),
            "the swipe policy must come from the value, so a renderer cannot quietly re-enable it"
        )
        XCTAssertFalse(
            list.contains("allowsFullSwipe: true"),
            "a full swipe running archive/restore is the bug #58 reports"
        )
    }

    func testSwipeMirrorsTheVisibleList() {
        XCTAssertEqual(
            EntryRowActions(showingArchived: false, dynamicTypeSize: .large).swipe,
            .archive
        )
        XCTAssertEqual(
            EntryRowActions(showingArchived: true, dynamicTypeSize: .large).swipe,
            .unarchive
        )
    }

    func testControlsMoveBelowTheRowAtAccessibilitySizes() {
        for size in [DynamicTypeSize.xSmall, .medium, .large, .xxxLarge] {
            XCTAssertFalse(
                EntryRowActions(showingArchived: false, dynamicTypeSize: size).stacksControlsBelowRow,
                "\(size) leaves enough width for a trailing pair"
            )
        }
        for size in [DynamicTypeSize.accessibility1, DynamicTypeSize.accessibility3, .accessibility5] {
            XCTAssertTrue(
                EntryRowActions(showingArchived: false, dynamicTypeSize: size).stacksControlsBelowRow,
                "\(size) cannot spare 108 points of row width"
            )
        }
    }
}
