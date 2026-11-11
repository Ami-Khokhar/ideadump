import XCTest
import SwiftData
@testable import TapLog

@MainActor
final class ReleaseReviewReproductionTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: Entry.self, SpendCategory.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    // Mirrors LogExpenseIntent/QuickLogIntent's insert -> failed save -> throw path.
    // Injected error models a refused save. It does not claim to induce low disk.
    func testReproducesFailedIntentInsertPersistingOnLaterSave() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.autosaveEnabled = false
        let refused = Entry(amount: 80, category: "chai", note: "refused")
        context.insert(refused)
        do {
            throw NSError(domain: "ReviewInjectedSaveFailure", code: 1)
        } catch {
            // Production catches/logs/throws without rollback or delete.
        }
        XCTAssertTrue(context.hasChanges)
        context.insert(Entry(amount: 80, category: "chai", note: "retry"))
        try context.save()
        let reader = ModelContext(container)
        let persisted = try reader.fetch(FetchDescriptor<Entry>())
        XCTAssertEqual(persisted.count, 2, "Both the refused attempt and retry were persisted")
        XCTAssertEqual(Set(persisted.compactMap(\.note)), ["refused", "retry"])
    }

    // Actual UndoStack plus the same independent permanent-delete sequence as Settings.
    func testReproducesUndoRestoringEntryAfterPermanentWipe() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let removed = Entry(amount: 80, category: "chai", note: "private")
        context.insert(removed)
        try context.save()
        let snapshot = DeletedEntrySnapshot(entry: removed)
        context.delete(removed)
        try context.save()
        let stack = UndoStack()
        stack.record("Deleted") {
            context.insert(snapshot.makeEntry())
            try! context.save()
        }
        context.insert(Entry(amount: 10, category: "food"))
        try context.save()
        for entry in try context.fetch(FetchDescriptor<Entry>()) { context.delete(entry) }
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Entry>()), 0)
        // Settings never invalidates the shared stack after the permanent wipe.
        stack.undo()
        let restored = try ModelContext(container).fetch(FetchDescriptor<Entry>())
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored.first?.note, "private")
    }

    func testReproducesCurrencyRelabelWithoutConversion() {
        let defaults = Money.sharedDefaults!
        let original = defaults.object(forKey: "currencyCode")
        defer {
            if let original { defaults.set(original, forKey: "currencyCode") }
            else { defaults.removeObject(forKey: "currencyCode") }
        }
        let entry = Entry(amount: 100, category: "chai")
        defaults.set("INR", forKey: "currencyCode")
        let before = Money.format(entry.amount)
        defaults.set("USD", forKey: "currencyCode")
        let after = Money.format(entry.amount)
        XCTAssertNotEqual(before, after)
        XCTAssertEqual(entry.amount, 100)
        let csv = CSVExporter.makeCSV(entries: [entry], lookup: CategoryLookup([]))
        XCTAssertFalse(csv.contains("INR"))
        XCTAssertFalse(csv.contains("USD"))
    }
    func testReproducesLocalizedShareAmountTruncation() {
        let parsed = ShareParser.parse("Paid €1.234,56 at Cafe")
        XCTAssertEqual(parsed.amount, Decimal(string: "1.23"))
        XCTAssertNotEqual(parsed.amount, Decimal(string: "1234.56"))
    }

    func testReproducesCategoryUsageDriftAfterEditingAndDeletingEntry() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let old = SpendCategory(key: "chai", name: "Chai", emoji: "☕️")
        let new = SpendCategory(key: "food", name: "Food", emoji: "🍽️")
        let categories = [old, new]
        context.insert(old); context.insert(new)
        let entry = Entry(amount: 80, category: "chai")
        context.insert(entry)
        try context.save()
        let defaults = UserDefaults(suiteName: "ReviewCategoryUsage-" + UUID().uuidString)!
        CaptureBookkeeping.apply(modelContext: context, categories: categories, categoryKey: "chai", defaults: defaults)
        // CaptureForm does not move category usage on a non-pending edit.
        entry.category = "food"
        try context.save()
        XCTAssertEqual(old.logCount, 1)
        XCTAssertEqual(new.logCount, 0)
        XCTAssertTrue(CaptureBookkeeping.undoLog(entry: entry, modelContext: context, categories: categories, defaults: defaults))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Entry>()), 0)
        XCTAssertEqual(old.logCount, 1, "Deleted history still ranks the original category")
    }
}
