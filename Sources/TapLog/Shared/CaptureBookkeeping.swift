import Foundation
import SwiftData
import WidgetKit

/// Bookkeeping applied once per newly-counted expense, shared by every capture
/// front door — home screen, capture form (deep links, pending-share
/// confirmations), Siri & Shortcuts, and widget quick-log — so category learning,
/// log totals, and streaks stay identical no matter where an expense entered
/// TapLog. `revert` is its exact inverse for undo.
enum CaptureBookkeeping {
    @MainActor
    static func apply(
        modelContext: ModelContext,
        categories: [SpendCategory],
        categoryKey: String,
        defaults: UserDefaults = StoreLocator.sharedDefaults
    ) {
        RetentionManager.migrateLegacyStateIfNeeded(target: defaults)

        // Category learning: drives chip sort order and tile suggestions.
        if let category = categories.first(where: { $0.key == categoryKey }) {
            category.logCount += 1
            do {
                try modelContext.save()
            } catch {
                print("TapLog: Failed to save category log count: \(error)")
            }
        }

        defaults.set(defaults.integer(forKey: "logsLogged") + 1, forKey: "logsLogged")

        // Streaks, weekly mask, streak-freeze awards.
        RetentionManager(defaults: defaults).recordLogDay()

        WidgetCenter.shared.reloadTimelines(ofKind: "SpendWidget")
    }

    /// Inverse of `apply` — call from undo closures after the entry has been
    /// deleted (or reverted to pending) AND successfully persisted. Restores
    /// counters to the pre-log state; earned streaks and freezes stay (see
    /// `RetentionManager.undoRecordLogDay`). Pass the undone entry's date so the
    /// right day's weekly bit is cleared — an undo after midnight must not clear
    /// today's bit for a yesterday log. Days from earlier weeks are left alone.
    @MainActor
    static func revert(
        modelContext: ModelContext,
        categories: [SpendCategory],
        categoryKey: String,
        entryDate: Date = .now,
        defaults: UserDefaults = StoreLocator.sharedDefaults
    ) {
        if let category = categories.first(where: { $0.key == categoryKey }) {
            category.logCount = max(0, category.logCount - 1)
            do {
                try modelContext.save()
            } catch {
                print("TapLog: Failed to save reverted category count: \(error)")
            }
        }

        defaults.set(max(0, defaults.integer(forKey: "logsLogged") - 1), forKey: "logsLogged")

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: entryDate)
        let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let descriptor = FetchDescriptor<Entry>(
            predicate: #Predicate {
                $0.date >= dayStart && $0.date < nextDayStart && !$0.isArchived && !$0.isPending
            }
        )
        let otherLogsRemainThatDay = ((try? modelContext.fetchCount(descriptor)) ?? 0) > 0

        RetentionManager(defaults: defaults).undoRecordLogDay(
            removingActiveDayFor: otherLogsRemainThatDay ? nil : entryDate
        )

        WidgetCenter.shared.reloadTimelines(ofKind: "SpendWidget")
    }

    /// Zeroes every category's usage counter — part of the clean-slate wipe when
    /// all entries are deleted, so tiles don't keep ranking deleted history.
    @MainActor
    static func resetCategoryUsage(modelContext: ModelContext) {
        let categories = (try? modelContext.fetch(FetchDescriptor<SpendCategory>())) ?? []
        for category in categories where category.logCount != 0 {
            category.logCount = 0
        }
        do {
            try modelContext.save()
        } catch {
            print("TapLog: Failed to reset category usage: \(error)")
        }
    }
}
