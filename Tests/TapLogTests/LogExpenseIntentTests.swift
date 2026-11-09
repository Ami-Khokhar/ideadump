import XCTest
import SwiftData
@testable import TapLog

/// The save half of `LogExpenseIntent.perform()`. `perform()` itself needs a live
/// store and Siri's parameter prompting, so the commit seam it calls is what is
/// driven here — including the refusal, which only an injected `save` closure
/// can produce. Before this, the intent's do/catch deleted the entry in a branch
/// no test could reach.
@MainActor
final class LogExpenseIntentTests: XCTestCase {

    private struct StoreRefused: Error {}

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Entry.self, SpendCategory.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// The shared main context survives a failed intent. The insert has to leave
    /// with the error, or a later save commits an expense Siri already reported
    /// as failed.
    func testRefusedSaveRemovesTheInsertedEntryAndThrows() throws {
        let context = try makeContext()
        let entry = Entry(amount: 42, category: "chai")
        context.insert(entry)

        XCTAssertThrowsError(
            try LogExpenseIntent.commitEntry(entry, in: context, save: { _ in throw StoreRefused() })
        ) { error in
            XCTAssertEqual(error as? TapLogIntentError, .saveFailed)
        }

        XCTAssertTrue(
            try context.fetch(FetchDescriptor<Entry>()).isEmpty,
            "an expense Siri reported as failed must not linger in the shared context"
        )
    }

    func testSuccessfulSaveKeepsTheEntry() throws {
        let context = try makeContext()
        let entry = Entry(amount: 42, category: "chai")
        context.insert(entry)

        try LogExpenseIntent.commitEntry(entry, in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Entry>()).count, 1)
    }
}
