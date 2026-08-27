import AppIntents
import Foundation
import SwiftData

/// A spending category, exposed to Siri and Shortcuts.
///
/// This exists so the category can be *spoken*. `AppShortcut` phrases may only
/// interpolate parameters whose type is an `AppEntity` or `AppEnum` — numbers and
/// plain strings are rejected by the metadata compiler — so a `String` parameter
/// could never appear in a phrase like "Log chai in TapLog". Modelling categories
/// as an entity also hands Siri the user's real category names to match against,
/// and gives the Shortcuts app a proper picker instead of a free-text field.
struct CategoryEntity: AppEntity, Identifiable {
    /// The stable `SpendCategory.key`. Using the key rather than the display name
    /// means renaming a category never breaks a shortcut the user already built.
    let id: String
    let name: String
    let emoji: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Category")
    }

    static var defaultQuery = CategoryEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(emoji) \(name)")
    }
}

/// Looks categories up from the live store.
///
/// Conforms to `EntityStringQuery` so Siri can resolve a spoken word to a
/// category; plain `EntityQuery` only covers identifier lookup, which is enough
/// for Shortcuts but not for voice.
struct CategoryEntityQuery: EntityStringQuery {

    @MainActor
    private func allCategories() -> [CategoryEntity] {
        guard let container = try? StoreLocator.container() else { return [] }
        let descriptor = FetchDescriptor<SpendCategory>(
            sortBy: [SortDescriptor(\.logCount, order: .reverse), SortDescriptor(\.sortOrder)]
        )
        let categories = (try? container.mainContext.fetch(descriptor)) ?? []
        return categories.map {
            CategoryEntity(id: $0.key, name: $0.name, emoji: $0.emoji)
        }
    }

    @MainActor
    func entities(for identifiers: [String]) async throws -> [CategoryEntity] {
        let wanted = Set(identifiers)
        return allCategories().filter { wanted.contains($0.id) }
    }

    /// Voice matching. Siri hands over roughly what it heard, so this accepts an
    /// exact key or name first and then falls back to a contains match — "coffee"
    /// should still find "Coffee & chai" rather than silently landing in Other.
    @MainActor
    func entities(matching string: String) async throws -> [CategoryEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return [] }
        let all = allCategories()
        let exact = all.filter { $0.id.lowercased() == needle || $0.name.lowercased() == needle }
        guard exact.isEmpty else { return exact }
        return all.filter { $0.name.lowercased().contains(needle) }
    }

    /// Shown in the Shortcuts picker. Most-used first, matching how the capture
    /// screen orders its tiles.
    @MainActor
    func suggestedEntities() async throws -> [CategoryEntity] {
        Array(allCategories().prefix(8))
    }
}
