import XCTest
import SwiftUI
@testable import TapLog

/// Issue #58: a History row must show edit and delete, and a full swipe must not
/// run archive/restore by itself. These assertions fail if either visible
/// control is dropped or `allowsFullSwipe` becomes true again.
final class EntryRowActionsTests: XCTestCase {

    func testActiveRowShowsBothControls() {
        let actions = EntryRowActions(showingArchived: false, dynamicTypeSize: .large)
        XCTAssertTrue(actions.showsEdit)
        XCTAssertTrue(actions.showsDelete)
    }

    func testArchivedRowShowsBothControls() {
        let actions = EntryRowActions(showingArchived: true, dynamicTypeSize: .large)
        XCTAssertTrue(actions.showsEdit)
        XCTAssertTrue(actions.showsDelete)
    }

    func testFullSwipeIsNeverAllowed() {
        for archived in [false, true] {
            for size in [DynamicTypeSize.xSmall, .large, .accessibility5] {
                let actions = EntryRowActions(showingArchived: archived, dynamicTypeSize: size)
                XCTAssertFalse(actions.allowsFullSwipe, "full swipe must stay deliberate")
            }
        }
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
