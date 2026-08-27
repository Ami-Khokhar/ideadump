import AppIntents
import Foundation
import SwiftData

/// The "Log Expense" action exposed to Siri and Shortcuts. It is headless: Siri asks
/// for any missing amount, saves the entry, and returns a spoken confirmation.
struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Expense"
    static var description = IntentDescription("Logs a purchase to TapLog.")
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Note")
    var note: String?

    /// An entity rather than a String so it can appear in an `AppShortcut` phrase
    /// ("Log chai in TapLog") — phrases only interpolate `AppEntity`/`AppEnum`.
    @Parameter(title: "Category")
    var category: CategoryEntity?

    @MainActor
    func perform() async throws -> some IntentResult {
        let validatedAmount = try TapLogIntentAmountValidator.validate(amount)
        // Reuses the process-wide container. Siri runs this intent inside the
        // app's own process, where a container is already open.
        let container = try StoreLocator.container()
        let context = container.mainContext
        let categories = (try? context.fetch(FetchDescriptor<SpendCategory>())) ?? []

        let categoryKey = Self.resolvedKey(
            entity: category,
            categories: categories,
            lastUsed: UserDefaults.standard.string(forKey: "lastUsedCategory")
        )

        let entry = Entry(amount: validatedAmount, category: categoryKey, note: note)
        context.insert(entry)
        do {
            try context.save()
        } catch {
            print("TapLog: Failed to save entry from Siri: \(error)")
            throw TapLogIntentError.saveFailed
        }

        // Same bookkeeping as the home screen: category learning, log totals, streaks.
        CaptureBookkeeping.apply(modelContext: context, categories: categories, categoryKey: categoryKey)
        OnboardingFlow.recordIntentUse(OnboardingFlow.logExpenseUsedKey)
        let categoryName = CategoryLookup(categories).name(for: categoryKey)
        return .result(dialog: "Logged \(Money.format(validatedAmount)) in \(categoryName).")
    }

    /// Voice logging used to file everything under "Other". `category` was an
    /// optional `String`, and Siri never prompts for optional parameters, so it
    /// always arrived nil and fell straight through to the fallback key. When
    /// nothing is spoken we now reuse the category the user last logged — the same
    /// one the capture screen preselects — before giving up on "Other".
    static func resolvedKey(
        entity: CategoryEntity?,
        categories: [SpendCategory],
        lastUsed: String?
    ) -> String {
        if let entity, categories.contains(where: { $0.key == entity.id }) {
            return entity.id
        }
        if let lastUsed, categories.contains(where: { $0.key == lastUsed }) {
            return lastUsed
        }
        return SpendCategory.fallbackKey
    }

    /// String-based resolution, kept for callers that only have text (deep links,
    /// Shortcuts actions built before categories were an entity).
    static func resolveCategoryKey(_ raw: String?, categories: [SpendCategory]) -> String {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return SpendCategory.fallbackKey
        }
        let lower = raw.lowercased()
        return categories.first {
            $0.key.lowercased() == lower || $0.name.lowercased() == lower
        }?.key ?? SpendCategory.fallbackKey
    }
}
