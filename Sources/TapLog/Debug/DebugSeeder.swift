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
        do {
            try context.save()
        } catch {
            print("TapLog: Failed to seed categories: \(error)")
        }
    }

    @MainActor
    static func seedIfRequested(container: ModelContainer) {
        guard ProcessInfo.processInfo.arguments.contains("-seedSampleData") else { return }
        let context = container.mainContext
        let existing = (try? context.fetchCount(FetchDescriptor<Entry>())) ?? 0
        guard existing == 0 else { return }
        seed(context: context)
    }

    @MainActor
    static func seed(context: ModelContext) {
        let calendar = Calendar.current
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)!.start
        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: thisWeekStart)!
        let today = calendar.startOfDay(for: .now)

        // Dates are placed in the past relative to today so the Recap chart
        // never shows future bars. The earliest seed entry is last week's
        // Monday; the latest is "yesterday" so today starts empty and feels
        // like the user's first real log.
        let samples: [(Decimal, String, String?, Date)] = [
            (4.50, "chai", "latte",              today.addingTimeInterval(-5 * 86400)),  // 5 days ago
            (12.50, "food", "lunch",             today.addingTimeInterval(-4 * 86400)),  // 4 days ago
            (3.25, "chai", nil,                  today.addingTimeInterval(-3 * 86400)),  // 3 days ago
            (45.00, "shopping", "groceries",     today.addingTimeInterval(-2 * 86400)),  // 2 days ago
            (22.00, "transport", "metro",        today.addingTimeInterval(-1 * 86400)),  // yesterday
            (8.75, "food", "dinner",             today.addingTimeInterval(-1 * 86400 + 7200)),  // yesterday evening
            (15.00, "fun", "movies",             lastWeekStart.addingTimeInterval(86400)),       // last week Tue
            (60.00, "bills", "electric",         lastWeekStart.addingTimeInterval(2 * 86400)),   // last week Wed
            (5.50, "chai", nil,                  lastWeekStart.addingTimeInterval(3 * 86400)),   // last week Thu
            (30.00, "shopping", "clothes",       lastWeekStart.addingTimeInterval(4 * 86400)),   // last week Fri
            (10.00, "health", "pharmacy",        lastWeekStart.addingTimeInterval(5 * 86400)),   // last week Sat
            (18.00, "food", "takeout",           lastWeekStart.addingTimeInterval(6 * 86400)),   // last week Sun
        ]

        var categories: [SpendCategory] = (try? context.fetch(FetchDescriptor<SpendCategory>())) ?? []

        for (amount, categoryKey, note, date) in samples {
            let entry = Entry(amount: amount, category: categoryKey, note: note, date: date)
            context.insert(entry)
            CaptureBookkeeping.apply(modelContext: context, categories: categories, categoryKey: categoryKey)
        }

        // Budgets, so the grove has something to show. The targets are chosen to
        // land on different tree states against the sample spend above: chai is
        // comfortably inside its target, food is close to it, and transport is
        // deliberately over so the clay "wilting" treatment is exercised.
        let demoBudgets: [(key: String, target: Decimal, period: BudgetPeriod)] = [
            ("chai", 40, .weekly),
            ("food", 120, .weekly),
            ("transport", 15, .weekly),
            ("shopping", 200, .monthly),
        ]
        for budget in demoBudgets {
            guard let category = categories.first(where: { $0.key == budget.key }) else { continue }
            category.budgetTarget = budget.target
            category.budgetPeriod = budget.period
            // Backdate the baseline so the previous period counts as comparable
            // and the recovery/steady states can actually appear.
            category.budgetHealthResetDate = lastWeekStart.addingTimeInterval(-86400)
        }

        do {
            try context.save()
        } catch {
            print("TapLog: Failed to save sample data: \(error)")
        }

        // Update streaks to reflect last week's activity.
        let retention = RetentionManager()
        _ = retention.daysLoggedThisWeek

        WidgetCenter.shared.reloadTimelines(ofKind: "SpendWidget")
    }
}
