import Foundation
import SwiftData
import WidgetKit

/// Seeds sample data. Called from the debug menu, and automatically at launch when the
/// process is started with `-seedSampleData` (e.g. from `simctl launch` for testing).
enum DebugSeeder {
    /// Seeds the default category set the first time the store is opened, so the
    /// capture form is never empty. Users can delete or extend these freely.
    @MainActor
    static func seedCategoriesIfNeeded(container: ModelContainer) {
        let context = container.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<SpendCategory>())) ?? 0
        guard count == 0 else { return }
        for (index, seed) in SpendCategory.defaultSeeds.enumerated() {
            context.insert(SpendCategory(
                key: seed.key, name: seed.name, emoji: seed.emoji, sortOrder: index
            ))
        }
        try? context.save()
    }

    @MainActor
    static func seedIfRequested(container: ModelContainer) {
        guard ProcessInfo.processInfo.arguments.contains("-seedSampleData") else { return }
        let context = container.mainContext
        let existing = (try? context.fetchCount(FetchDescriptor<Entry>())) ?? 0
        guard existing == 0 else { return }
        seed(context: context)
    }

    static func seed(context: ModelContext) {
        let calendar = Calendar.current
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)!.start
        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: thisWeekStart)!

        let samples: [(Decimal, String, String?, Date)] = [
            (4.50, "coffee", "latte", thisWeekStart.addingTimeInterval(3600)),
            (12.50, "food", "lunch", thisWeekStart.addingTimeInterval(86400)),
            (3.25, "coffee", nil, thisWeekStart.addingTimeInterval(2 * 86400)),
            (45.00, "shopping", "groceries", thisWeekStart.addingTimeInterval(3 * 86400)),
            (22.00, "transport", "gas", thisWeekStart.addingTimeInterval(4 * 86400)),
            (8.75, "food", "dinner", thisWeekStart.addingTimeInterval(5 * 86400)),
            (15.00, "fun", "movies", lastWeekStart.addingTimeInterval(3600)),
            (60.00, "bills", "electric", lastWeekStart.addingTimeInterval(86400)),
            (5.50, "coffee", nil, lastWeekStart.addingTimeInterval(2 * 86400)),
            (30.00, "shopping", "clothes", lastWeekStart.addingTimeInterval(3 * 86400)),
            (10.00, "health", "pharmacy", lastWeekStart.addingTimeInterval(4 * 86400)),
            (18.00, "food", "takeout", lastWeekStart.addingTimeInterval(5 * 86400)),
        ]

        for (amount, category, note, date) in samples {
            context.insert(Entry(amount: amount, category: category, note: note, date: date))
        }
        try? context.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "SpendWidget")
    }
}
