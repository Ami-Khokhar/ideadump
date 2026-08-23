import Foundation
import SwiftData

@Model
final class Entry {
    var amount: Decimal
    var category: String
    var note: String?
    var date: Date
    var isArchived: Bool
    var isPending: Bool
    var isPlanned: Bool
    var createdAt: Date

    init(
        amount: Decimal,
        category: String,
        note: String? = nil,
        date: Date = .now,
        isArchived: Bool = false,
        isPending: Bool = false,
        isPlanned: Bool = false
    ) {
        self.amount = amount
        self.category = category
        self.note = note
        self.date = date
        self.isArchived = isArchived
        self.isPending = isPending
        self.isPlanned = isPlanned
        self.createdAt = .now
    }
}
