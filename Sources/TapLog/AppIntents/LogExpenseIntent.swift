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

    @Parameter(title: "Category")
    var category: String?

    @MainActor
    func perform() async throws -> some IntentResult {
        let validatedAmount = try TapLogIntentAmountValidator.validate(amount)
        let container = StoreLocator.makeContainer()
        let context = container.mainContext
        let categories = (try? context.fetch(FetchDescriptor<SpendCategory>())) ?? []

        let categoryKey = Self.resolveCategoryKey(category, categories: categories)

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
