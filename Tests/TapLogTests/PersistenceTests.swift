import XCTest
import SwiftData
@testable import TapLog

/// SwiftData round trips, seeding, and the category system entries reference
/// by stable key.
@MainActor
final class PersistenceTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Entry.self, SpendCategory.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    // MARK: - Entry round trip

    func testEntryRoundTripsAllFields() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let date = Date(timeIntervalSince1970: 1_750_000_000)
        let entry = Entry(
            amount: Decimal(string: "12.99")!,
            category: "chai",
            note: "morning",
            date: date,
            isPending: true,
            intent: .planned
        )
        context.insert(entry)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Entry>()).first!
        XCTAssertEqual(fetched.amount, Decimal(string: "12.99")!, "cent precision must survive persistence")
        XCTAssertEqual(fetched.category, "chai")
        XCTAssertEqual(fetched.note, "morning")
        XCTAssertEqual(fetched.date, date)
        XCTAssertTrue(fetched.isPending)
        XCTAssertEqual(fetched.intent, .planned)
    }

    // MARK: - Intent (three states, and the migration into them)

    /// The field exists to make "never answered" survivable, so nil has to be the
    /// default and has to round-trip as nil rather than collapsing to a Bool.
    func testEntryIntentDefaultsToUnmarkedAndRoundTripsEachState() throws {
        let container = try makeContainer()
        let context = container.mainContext
        XCTAssertNil(Entry(amount: 1, category: "chai").intent)

        context.insert(Entry(amount: 1, category: "chai"))
        context.insert(Entry(amount: 2, category: "chai", intent: .impulse))
        context.insert(Entry(amount: 3, category: "chai", intent: .planned))
        try context.save()

        let fetched = try context.fetch(
            FetchDescriptor<Entry>(sortBy: [SortDescriptor(\Entry.amount)])
        )
        XCTAssertNil(fetched[0].intent, "an untouched entry must persist as unmarked")
        XCTAssertEqual(fetched[1].intent, .impulse)
        XCTAssertEqual(fetched[2].intent, .planned)
    }

    /// Pre-`intent` builds stored a plain Bool. A legacy `true` was a deliberate
    /// tap and is worth keeping; a legacy `false` is indistinguishable from never
    /// having touched the control, so it must stay unmarked rather than becoming
    /// "impulse" — that mistake is the whole reason the field was replaced.
    @MainActor
    func testLegacyPlannedFlagMigratesOnlyTheDeliberateTrues() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let legacyPlanned = Entry(amount: 10, category: "chai")
        legacyPlanned.isPlanned = true
        let legacyUntouched = Entry(amount: 20, category: "chai")
        legacyUntouched.isPlanned = false
        context.insert(legacyPlanned)
        context.insert(legacyUntouched)
        try context.save()

        Entry.migrateLegacyPlannedMarks(container: container)

        let fetched = try context.fetch(
            FetchDescriptor<Entry>(sortBy: [SortDescriptor(\Entry.amount)])
        )
        XCTAssertEqual(fetched[0].intent, .planned)
        XCTAssertNil(fetched[1].intent, "a legacy false carries no intent and must stay unmarked")
    }

    /// The migration runs at every launch, so it must never overwrite an answer
    /// the user has since changed.
    @MainActor
    func testLegacyMigrationLeavesAlreadyMarkedEntriesAlone() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let entry = Entry(amount: 10, category: "chai", intent: .impulse)
        entry.isPlanned = true // as if migrated once, then corrected by the user
        context.insert(entry)
        try context.save()

        Entry.migrateLegacyPlannedMarks(container: container)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Entry>()).first?.intent, .impulse)
    }

    // MARK: - Visibility predicates (what each screen shows)

    func testActivePredicateExcludesArchivedAndPending() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(Entry(amount: 10, category: "chai"))
        context.insert(Entry(amount: 20, category: "chai", isArchived: true))
        context.insert(Entry(amount: 30, category: "chai", isPending: true))
        try context.save()

        var descriptor = FetchDescriptor<Entry>(
            predicate: #Predicate { !$0.isArchived && !$0.isPending }
        )
        XCTAssertEqual(try context.fetchCount(descriptor), 1)

        descriptor.predicate = #Predicate { $0.isPending }
        XCTAssertEqual(try context.fetchCount(descriptor), 1, "pending share entries must be findable for confirmation")

        descriptor.predicate = #Predicate { $0.isArchived }
        XCTAssertEqual(try context.fetchCount(descriptor), 1)
    }

    // MARK: - Seeding

    func testSeedingRunsOnceAndMatchesDefaultSet() throws {
        let container = try makeContainer()
        DebugSeeder.seedCategoriesIfNeeded(container: container)
        DebugSeeder.seedCategoriesIfNeeded(container: container) // second call is a no-op

        let categories = try container.mainContext.fetch(FetchDescriptor<SpendCategory>())
        XCTAssertEqual(categories.count, SpendCategory.defaultSeeds.count)
        XCTAssertEqual(Set(categories.map(\.key)), Set(SpendCategory.defaultSeeds.map(\.key)))
    }

    // MARK: - Custom category keys

    func testMakeKeySlugsAndDeduplicates() {
        let existing = [
            SpendCategory(key: "chai", name: "Chai", emoji: "☕️"),
        ]
        XCTAssertEqual(SpendCategory.makeKey(forName: "Café Latte", existing: []), "cafe-latte")
        XCTAssertEqual(SpendCategory.makeKey(forName: "Chai", existing: existing), "chai-2")
        XCTAssertEqual(SpendCategory.makeKey(forName: "!!!", existing: []), "custom")
        XCTAssertEqual(
            SpendCategory.makeKey(forName: "Chai", existing: existing + [SpendCategory(key: "chai-2", name: "x", emoji: "x")]),
            "chai-3"
        )
    }

    func testMakeKeyAvoidsKeysStillReferencedByEntries() {
        // The category was deleted but its key lives on in history — a new category
        // with the same name must not reclaim that key, or old entries would
        // silently reattach to it.
        XCTAssertEqual(
            SpendCategory.makeKey(forName: "Chai", existing: [], takenKeys: ["chai"]),
            "chai-2"
        )
        XCTAssertEqual(
            SpendCategory.makeKey(forName: "Chai", existing: [], takenKeys: ["chai", "chai-2"]),
            "chai-3"
        )
        // Keys nobody references remain free.
        XCTAssertEqual(
            SpendCategory.makeKey(forName: "Chai", existing: [], takenKeys: ["food"]),
            "chai"
        )
    }

    // MARK: - Lookup fallback (deleted categories must never break display)

    func testLookupFallsBackForDeletedCategory() {
        let lookup = CategoryLookup([SpendCategory(key: "chai", name: "Chai", emoji: "☕️")])
        XCTAssertEqual(lookup.name(for: "chai"), "Chai")
        XCTAssertEqual(lookup.name(for: "deleted-key"), "Other")
        XCTAssertEqual(lookup.emoji(for: "deleted-key"), "🏷️")
        XCTAssertNil(lookup.category(for: "deleted-key"))
    }

    // MARK: - Budget field defaults & round-trip

    func testCategoryDefaultsBudgetFieldsToNil() throws {
        // Pre-budget categories were inserted via the original init; they must
        // remain valid (no budget configured) after the lightweight migration.
        let container = try makeContainer()
        let context = container.mainContext
        let category = SpendCategory(key: "chai", name: "Chai", emoji: "☕️")
        XCTAssertNil(category.budgetTarget)
        XCTAssertNil(category.budgetPeriod)

        context.insert(category)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<SpendCategory>()).first!
        XCTAssertNil(fetched.budgetTarget, "budget target must default to nil so existing categories stay valid")
        XCTAssertNil(fetched.budgetPeriod, "budget period must default to nil so existing categories stay valid")
    }

    func testCategoryBudgetRoundTrips() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let category = SpendCategory(
            key: "food",
            name: "Food",
            emoji: "🍽️",
            budgetTarget: Decimal(string: "250.00"),
            budgetPeriod: .monthly
        )
        context.insert(category)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SpendCategory>()).first!
        XCTAssertEqual(fetched.budgetTarget, Decimal(string: "250.00"))
        XCTAssertEqual(fetched.budgetPeriod, .monthly)
        XCTAssertNil(fetched.budgetHealthResetDate)
    }

    func testBudgetHealthResetDateRoundTrips() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let resetDate = Date(timeIntervalSince1970: 1_750_000_000)
        let category = SpendCategory(
            key: "food",
            name: "Food",
            emoji: "🍽️",
            budgetTarget: Decimal(string: "250.00"),
            budgetPeriod: .monthly,
            budgetHealthResetDate: resetDate
        )
        context.insert(category)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SpendCategory>()).first!
        XCTAssertEqual(fetched.budgetHealthResetDate, resetDate)
    }

    // MARK: - Undo snapshot round trip

    /// Undoing a delete has to hand back the same entry, `intent` included. This
    /// is the field most at risk: it was added last, so a snapshot that silently
    /// drops it would look correct in every other respect while quietly throwing
    /// away the one answer the user gave by hand.
    func testDeletedEntrySnapshotRoundTripsIntent() {
        for intent in [SpendIntent.impulse, .planned, nil] as [SpendIntent?] {
            let entry = Entry(
                amount: Decimal(string: "12.99")!,
                category: "chai",
                note: "morning",
                date: Date(timeIntervalSince1970: 1_750_000_000),
                isArchived: true,
                intent: intent
            )
            let restored = DeletedEntrySnapshot(entry: entry).makeEntry()
            XCTAssertEqual(restored.intent, intent)
            XCTAssertEqual(restored.amount, entry.amount)
            XCTAssertEqual(restored.category, entry.category)
            XCTAssertEqual(restored.note, entry.note)
            XCTAssertEqual(restored.date, entry.date)
            XCTAssertEqual(restored.isArchived, entry.isArchived)
        }
    }

    func testEditCategorySnapshotRestoresAllEditedFields() {
        let category = SpendCategory(
            key: "food",
            name: "Food",
            emoji: "🍽️",
            budgetTarget: Decimal(string: "250.00"),
            budgetPeriod: .monthly
        )
        let original = EditCategorySnapshot(category: category)

        category.name = "Dining"
        category.emoji = "🍜"
        category.budgetTarget = nil
        category.budgetPeriod = nil

        original.restore(to: category)

        XCTAssertEqual(category.name, "Food")
        XCTAssertEqual(category.emoji, "🍽️")
        XCTAssertEqual(category.budgetTarget, Decimal(string: "250.00"))
        XCTAssertEqual(category.budgetPeriod, .monthly)
    }
}
