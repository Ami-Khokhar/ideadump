import AppIntents
import SwiftData
import WidgetKit

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
        let container = StoreLocator.makeContainer()
        let context = container.mainContext
        let categories = (try? context.fetch(FetchDescriptor<SpendCategory>())) ?? []
        let categoryKey = categories.first { $0.key == category }?.key
            ?? categories.first?.key
            ?? SpendCategory.fallbackKey
        let entry = Entry(amount: Money.fromAmount(amount), category: categoryKey, note: nil)
        context.insert(entry)
        try context.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "SpendWidget")
        return .result()
    }
}
