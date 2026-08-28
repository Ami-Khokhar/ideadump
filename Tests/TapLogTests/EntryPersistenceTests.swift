import XCTest
import SwiftData
@testable import TapLog

/// The save-refusal path, which used to `print` and return — leaving the user
/// with no row, no message, and a cleared amount field.
@MainActor
final class EntryPersistenceTests: XCTestCase {

    private struct StoreRefused: Error {}

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Entry.self, SpendCategory.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // MARK: - Refusal

    func testRefusalRollsBackReportsAndReturnsFalse() {
        var reported: [String] = []
        var rolledBack = false

        let committed = EntryPersistence.commit(
            message: EntryPersistence.insertFailureMessage,
            save: { throw StoreRefused() },
            rollback: { rolledBack = true },
            report: { reported.append($0) }
        )

        XCTAssertFalse(committed, "callers must be able to stop before their success bookkeeping")
        XCTAssertTrue(rolledBack, "an entry the store refused must not linger in memory")
        XCTAssertEqual(reported, [EntryPersistence.insertFailureMessage])
    }

    func testRefusalRemovesTheInsertedEntryFromTheContext() throws {
        let context = try makeContext()
        let entry = Entry(amount: 42, category: "chai")
        context.insert(entry)

        _ = EntryPersistence.commit(
            message: EntryPersistence.insertFailureMessage,
            save: { throw StoreRefused() },
            rollback: { context.delete(entry) },
            report: { _ in }
        )

        let remaining = try context.fetch(FetchDescriptor<Entry>())
        XCTAssertTrue(remaining.isEmpty, "a refused expense must not survive as a phantom row")
    }

    /// The messages have to say the thing did not happen, and stay short enough
    /// to sit on one line — a taller toast grows up into the category tiles it
    /// is drawn over, and it is hit-testable.
    func testFailureMessagesAreDistinctAndShortEnoughForOneLine() {
        for message in [EntryPersistence.insertFailureMessage, EntryPersistence.editFailureMessage] {
            XCTAssertFalse(message.isEmpty)
            XCTAssertTrue(message.lowercased().hasPrefix("couldn't save"), "lead with the failure, not the remedy")
            XCTAssertLessThanOrEqual(message.count, 44, "longer than this wraps the toast onto a second line")
        }
        XCTAssertNotEqual(EntryPersistence.insertFailureMessage, EntryPersistence.editFailureMessage)
    }

    // MARK: - Success

    func testSuccessReportsNothingAndDoesNotRollBack() throws {
        let context = try makeContext()
        let entry = Entry(amount: 42, category: "chai")
        context.insert(entry)
        var reported: [String] = []
        var rolledBack = false

        let committed = EntryPersistence.commit(
            message: EntryPersistence.insertFailureMessage,
            save: { try context.save() },
            rollback: { rolledBack = true },
            report: { reported.append($0) }
        )

        XCTAssertTrue(committed)
        XCTAssertFalse(rolledBack)
        XCTAssertTrue(reported.isEmpty, "a successful save must stay silent")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Entry>()).count, 1)
    }

    // MARK: - How the toast presents it

    func testReportedFailureIsShownButNotUndoable() {
        let stack = UndoStack()
        stack.report(EntryPersistence.insertFailureMessage)

        XCTAssertEqual(stack.current?.message, EntryPersistence.insertFailureMessage)
        XCTAssertFalse(stack.current?.isUndoable ?? true, "there is no inverse of a save that never happened")
        XCTAssertNil(stack.current?.tree, "a refusal moved no budget tree")
    }

    /// A failure notice can appear while an earlier log is still undoable. Undo
    /// must not quietly reverse that earlier log while the user is looking at
    /// the failure.
    func testUndoDoesNothingWhileAFailureIsShowing() {
        let stack = UndoStack()
        var undone = false
        stack.record("Logged ₹10 · Chai") { undone = true }
        stack.report(EntryPersistence.insertFailureMessage)

        stack.undo()

        XCTAssertFalse(undone, "the visible action is the failure, which has nothing to undo")
    }

    /// Once a real action is showing again, Undo works as before.
    func testUndoStillWorksForTheActionShownAfterAFailure() {
        let stack = UndoStack()
        var undone = false
        stack.report(EntryPersistence.insertFailureMessage)
        stack.record("Logged ₹10 · Chai") { undone = true }

        stack.undo()

        XCTAssertTrue(undone)
    }
}
