import AppIntents
import SwiftData
import WidgetKit

/// The "Log Expense" action exposed to Siri and Shortcuts. The Action Button (M2/M6)
/// points at a Shortcut that calls this.
struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Expense"
    static var description = IntentDescription("Logs a purchase to TapLog.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Note")
    var note: String?

    @Parameter(title: "Category")
    var category: String?

    @MainActor
    func perform() async throws -> some IntentResult {
        let container = StoreLocator.makeContainer()
        let context = container.mainContext
        let categories = (try? context.fetch(FetchDescriptor<SpendCategory>())) ?? []

        let categoryKey: String
        if let raw = category?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            let lower = raw.lowercased()
            categoryKey = categories.first {
                $0.key.lowercased() == lower || $0.name.lowercased() == lower
            }?.key ?? categories.first?.key ?? SpendCategory.fallbackKey
        } else {
            categoryKey = categories.first?.key ?? SpendCategory.fallbackKey
        }

        let entry = Entry(amount: Decimal(amount), category: categoryKey, note: note)
        context.insert(entry)
        try context.save()

        WidgetCenter.shared.reloadTimelines(ofKind: "SpendWidget")
        return .result()
    }
}
