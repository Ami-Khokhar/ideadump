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

    func testActiveRowShowsBothControls() {
        let actions = EntryRowActions(showingArchived: false, dynamicTypeSize: .large)
        XCTAssertTrue(actions.showsEdit, "History must offer edit on an active row")
        XCTAssertTrue(actions.showsDelete, "History must offer delete on an active row")
    }

    func testArchivedRowShowsBothControls() {
        let actions = EntryRowActions(showingArchived: true, dynamicTypeSize: .large)
        XCTAssertTrue(actions.showsEdit, "an archived row must still be editable")
        XCTAssertTrue(actions.showsDelete, "an archived row must still be deletable")
    }

    func testFullSwipeIsNeverAllowed() {
        for archived in [false, true] {
            for size in [DynamicTypeSize.xSmall, .large, .accessibility5] {
                let actions = EntryRowActions(showingArchived: archived, dynamicTypeSize: size)
                XCTAssertFalse(actions.allowsFullSwipe, "a full swipe must stay deliberate at \(size)")
            }
        }
    }

    /// The rendering half of the behaviour lives in a `View`, which the test
    /// target cannot tap, so the call site is asserted against the list's source
    /// the way `ShareOutcomeTests.testTheExtensionShowsTheSharedOutcome` asserts
    /// the share extension. This cannot see inside the row body — deleting the
    /// trash `Button` would pass — and it is sensitive to formatting. It covers
    /// exactly one thing: the list must not pass its own full-swipe literal, and
    /// must call the renderer that draws the two controls.
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
        XCTAssertTrue(
            list.contains("Button(role: .destructive)"),
            "the row's delete control must be the destructive one VoiceOver announces"
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
