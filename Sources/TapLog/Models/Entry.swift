import Foundation
import SwiftData

/// Whether a purchase was deliberate. Deliberately *not* a `Bool`: the property
/// that stores it is optional, and `nil` — "the user never said" — is a real,
/// distinct answer that has to survive all the way to the recap.
///
/// An earlier build stored this as a plain `Bool`, which could not express it: a
/// non-optional flag defaulting to `false` made "I meant to buy this" and "I never
/// touched the control" the same value, so any share computed from it would have
/// told a user who ignores the toggle that all of their spending was impulsive.
/// Every number the app shows on this axis is computed over marked entries only.
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
        self.intent = intent
        self.createdAt = .now
    }
}
