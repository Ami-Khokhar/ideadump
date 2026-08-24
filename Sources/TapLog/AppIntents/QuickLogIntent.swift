import AppIntents
import SwiftData

/// One-tap logging from the interactive widget. Runs in the widget's own process with
/// `openAppWhenRun = false`, so the app never appears on screen.
struct QuickLogIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Log"
    static var description = IntentDescription("Logs an expense instantly without opening TapLog.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Category")
    var category: String

    init() {}

    init(amount: Double, category: String) {
        self.amount = amount
        self.category = category
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let validatedAmount = try TapLogIntentAmountValidator.validate(amount)
        let container = StoreLocator.makeContainer()
        let context = container.mainContext
        let categories = (try? context.fetch(FetchDescriptor<SpendCategory>())) ?? []
        let categoryKey = categories.first { $0.key == category }?.key
            ?? categories.first?.key
            ?? SpendCategory.fallbackKey
        let entry = Entry(amount: validatedAmount, category: categoryKey, note: nil)
        context.insert(entry)
        do {
            try context.save()
        } catch {
            print("TapLog: Failed to save quick log: \(error)")
            throw TapLogIntentError.saveFailed
        }

        // Same bookkeeping as the home screen: category learning, log totals, streaks.
        CaptureBookkeeping.apply(modelContext: context, categories: categories, categoryKey: categoryKey)
        return .result()
    }
}
