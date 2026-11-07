import XCTest
import SwiftData
@testable import TapLog

/// The category lookup Siri resolves against. Store-open and fetch failures used
/// to become an empty list, so Siri could not tell "no categories" from "the
/// store is broken" and turned a real problem into an unresolvable parameter.
/// Each branch is driven through the injectable boundaries on `allCategories`,
/// so reverting either throw to `try?` / `?? []` fails here.
@MainActor
final class CategoryEntityQueryTests: XCTestCase {

    private struct StoreUnreachable: Error {}

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Entry.self, SpendCategory.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// A regular file occupying the store's parent path makes the open fail for
    /// real — the same shape as StoreLocatorTests' sandbox-denied candidate.
    func testUnopenableStoreSurfacesCategoriesUnavailable() throws {
        let fm = FileManager.default
        let blocked = fm.temporaryDirectory
            .appendingPathComponent("taplog-category-blocked-\(UUID().uuidString)")
        try Data().write(to: blocked)
        defer { try? fm.removeItem(at: blocked) }

        let query = CategoryEntityQuery()
        XCTAssertThrowsError(
            try query.allCategories(container: {
                try ModelContainer(
                    for: Entry.self, SpendCategory.self,
                    configurations: ModelConfiguration(
                        url: blocked.appendingPathComponent(StoreLocator.storeFileName)
                    )
                )
            })
        ) { error in
            XCTAssertEqual(error as? TapLogIntentError, .categoriesUnavailable)
        }
    }

    func testFetchFailureSurfacesCategoriesUnavailable() throws {
        let container = try makeContainer()
        let query = CategoryEntityQuery()

        XCTAssertThrowsError(
            try query.allCategories(
                container: { container },
                fetch: { _, _ in throw StoreUnreachable() }
            )
        ) { error in
            XCTAssertEqual(error as? TapLogIntentError, .categoriesUnavailable)
        }
    }

    func testHealthyStoreReturnsItsCategories() throws {
        let container = try makeContainer()
        container.mainContext.insert(
            SpendCategory(key: "chai", name: "Chai", emoji: "☕️", logCount: 3)
        )
        container.mainContext.insert(
            SpendCategory(key: "food", name: "Food", emoji: "🍽️", logCount: 9)
        )
        try container.mainContext.save()

        let categories = try CategoryEntityQuery().allCategories(container: { container })

        XCTAssertEqual(categories.map(\.id), ["food", "chai"], "most-used first")
        XCTAssertEqual(categories.first?.name, "Food")
    }

    /// An empty store is a valid answer, not a failure. This is the distinction
    /// the old `?? []` erased.
    func testHealthyStoreWithNoCategoriesReturnsEmptyInsteadOfThrowing() throws {
        let container = try makeContainer()

        let categories = try CategoryEntityQuery().allCategories(container: { container })

        XCTAssertTrue(categories.isEmpty)
    }
}
