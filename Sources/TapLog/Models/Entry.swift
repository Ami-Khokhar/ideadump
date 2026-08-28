import Foundation
import SwiftData

/// Whether a purchase was deliberate. Deliberately *not* a `Bool`: the property
/// that stores it is optional, and `nil` — "the user never said" — is a real,
/// distinct answer that has to survive all the way to the recap.
///
/// The old `isPlanned: Bool` could not express that. A non-optional flag defaulting
/// to `false` made "I meant to buy this" and "I never touched the control" the same
/// value, so any share computed from it would have told a user who ignores the
/// toggle that all of their spending was impulsive. Every number the app shows on
/// this axis is computed over marked entries only.
enum SpendIntent: String, Codable, CaseIterable, Sendable {
    case impulse
    case planned
}

@Model
final class Entry {
    var amount: Decimal
    var category: String
    var note: String?
    var date: Date
    var isArchived: Bool
    var isPending: Bool
    /// Legacy two-state flag, kept only so `migrateLegacyPlannedMarks` can rescue
    /// the deliberate "Planned" taps recorded by builds that shipped before
    /// `intent` existed. Nothing writes it any more and nothing should read it
    /// outside that migration — a `false` here means nothing at all.
    var isPlanned: Bool
    /// Impulse / planned, or nil for unmarked. Optional so entries persisted before
    /// this field existed round-trip cleanly through SwiftData's lightweight
    /// migration *and* land in the honest state: unmarked.
    var intent: SpendIntent?
    var createdAt: Date

    init(
        amount: Decimal,
        category: String,
        note: String? = nil,
        date: Date = .now,
        isArchived: Bool = false,
        isPending: Bool = false,
        intent: SpendIntent? = nil
    ) {
        self.amount = amount
        self.category = category
        self.note = note
        self.date = date
        self.isArchived = isArchived
        self.isPending = isPending
        self.isPlanned = false
        self.intent = intent
        self.createdAt = .now
    }

    /// Carries pre-`intent` "Planned" taps forward. A legacy `true` was unambiguous —
    /// the user reached for the control and said so — whereas a legacy `false` is
    /// indistinguishable from never having touched it, so only `true` is migrated
    /// and everything else stays unmarked.
    ///
    /// Runs once per row and then cannot run again: the legacy flag is cleared
    /// as each entry is carried over, so the next fetch no longer matches it.
    ///
    /// Clearing matters. Only setting `intent` left `isPlanned` true forever,
    /// which made the migration idempotent only while `intent` stayed non-nil —
    /// clear an entry's intent and the next launch would silently re-mark it
    /// `.planned`, restoring a mark the user had removed. Consuming the flag
    /// makes the carry-over genuinely one-way.
    @MainActor
    static func migrateLegacyPlannedMarks(container: ModelContainer) {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.isPlanned })
        guard let legacy = try? context.fetch(descriptor) else { return }
        guard !legacy.isEmpty else { return }
        for entry in legacy {
            // A row that already carries an intent has been decided — by an
            // earlier run or by the user — so only the flag is consumed.
            if entry.intent == nil {
                entry.intent = .planned
            }
            entry.isPlanned = false
        }
        do {
            try context.save()
        } catch {
            print("TapLog: Failed to migrate legacy planned marks: \(error)")
        }
    }
}
