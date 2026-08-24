import XCTest
@testable import TapLog

/// Undo must pop most-recent-first and always run the inverse operation.
@MainActor
final class UndoStackTests: XCTestCase {
    private var undoStack: UndoStack!

    override func setUp() {
        super.setUp()
        undoStack = UndoStack()
    }

    func testRecordExposesLatestAction() {
        undoStack.record("Logged ₹10") {}
        XCTAssertEqual(undoStack.current?.message, "Logged ₹10")
    }

    func testUndoRunsInverseAndClearsToast() {
        var undone = false
        undoStack.record("Logged ₹10") { undone = true }

        undoStack.undo()

        XCTAssertTrue(undone)
        XCTAssertNil(undoStack.current)
    }

    func testUndoIsLIFOAcrossMultipleRecords() {
        var order: [String] = []
        undoStack.record("First") { order.append("undo-first") }
        undoStack.record("Second") { order.append("undo-second") }
        XCTAssertEqual(undoStack.current?.message, "Second", "toast always shows the newest action")

        // Undoing clears the toast (it doesn't re-reveal the previous action),
        // but repeated undos still walk the history newest-first.
        undoStack.undo()
        XCTAssertEqual(order, ["undo-second"])
        XCTAssertNil(undoStack.current)

        undoStack.undo()
        XCTAssertEqual(order, ["undo-second", "undo-first"])
    }

    func testUndoWithEmptyStackIsANoOp() {
        undoStack.undo()
        XCTAssertNil(undoStack.current)
    }
}
