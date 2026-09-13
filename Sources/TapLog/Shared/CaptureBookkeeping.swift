import Foundation
import SwiftData
import WidgetKit

/// Bookkeeping applied once per newly-counted expense, shared by every capture
/// front door — home screen, capture form (deep links, pending-share
/// confirmations), Siri & Shortcuts, and widget quick-log — so category learning,
/// log totals, and streaks stay identical no matter where an expense entered
/// TapLog. `revert` is its exact inverse.
///
/// "Counted" means a confirmed, unarchived entry — the same set every query in
/// the app filters for. So the pair is called for more than undo: archiving
/// takes an entry out of that set and reverts, unarchiving puts it back and
/// applies, and deleting reverts for good.
enum CaptureBookkeeping {
    @MainActor
    static func apply(
        modelContext: ModelContext,
        categories: [SpendCategory],
        categoryKey: String,
        entryDate: Date = .now,
        defaults: UserDefaults = StoreLocator.sharedDefaults
    ) {
        RetentionManager.migrateLegacyStateIfNeeded(target: defaults)

        // Category learning: drives chip sort order and tile suggestions.
        if let category = categories.first(where: { $0.key == categoryKey }) {
            category.logCount += 1
            do {
                try modelContext.save()
            } catch {
                Log.capture.error("Failed to save category log count: \(Log.describe(error), privacy: .public)")
            }
        }

        defaults.set(defaults.integer(forKey: "logsLogged") + 1, forKey: "logsLogged")

        // Streaks, weekly mask, streak-freeze awards.
        RetentionManager(defaults: defaults).recordLogDay(on: entryDate)

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
                Log.capture.error("Failed to save reverted category count: \(Log.describe(error), privacy: .public)")
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

    /// Deletes a logged entry and takes its bookkeeping back with it.
    ///
    /// `revert` alone is only half an undo — it fixes the counters and leaves the
    /// row. The two halves have to stay together, and in the right order: the
    /// counters are only safe to move once the store has accepted the delete.
    ///
    /// Returns false when the store refuses, in which case nothing was reverted
    /// and the entry is still the user's. The rollback is what makes that second
    /// half true: `delete` only stages the removal, so without it the next
    /// successful save from anywhere in the app would commit this one behind the
    /// user's back — long after the toast said the undo had failed.
    @MainActor
    @discardableResult
    static func undoLog(
        entry: Entry,
        modelContext: ModelContext,
        categories: [SpendCategory],
        defaults: UserDefaults = StoreLocator.sharedDefaults
    ) -> Bool {
        // Read before the delete: afterwards the object is no longer in the store
        // and its properties are not ours to trust.
        let categoryKey = entry.category
        let entryDate = entry.date

        modelContext.delete(entry)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            Log.capture.error("Failed to undo a logged entry: \(Log.describe(error), privacy: .public)")
            return false
        }

        revert(
            modelContext: modelContext,
            categories: categories,
            categoryKey: categoryKey,
            entryDate: entryDate,
            defaults: defaults
        )
        return true
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
            Log.capture.error("Failed to reset category usage: \(Log.describe(error), privacy: .public)")
        }
    }
}
