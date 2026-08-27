import Foundation
import SwiftData

/// How an optional `budgetTarget` on `SpendCategory` resets.
enum BudgetPeriod: String, Codable, CaseIterable, Sendable {
    case weekly
    case monthly
}

/// A user-managed spending category. Entries reference categories by their stable
/// `key` string, so renaming or deleting a category never breaks an entry — display
/// simply falls back to "Other".
@Model
final class SpendCategory {
    var key: String
    var name: String
    var emoji: String
    var sortOrder: Int
    /// Number of times this category has been used — drives chip sort order and tile suggestions.
    var logCount: Int = 0
    /// Optional per-period spend target. When nil, the category has no budget configured.
    /// Backed by a Decimal so currency math stays exact; defaults to nil so categories
    /// persisted before this field existed remain valid (SwiftData lightweight migration).
    /// Changing either budget setting resets the tree-health baseline. This prevents a
    /// new target from silently reclassifying a period that was resolved under the old
    /// configuration.
    var budgetTarget: Decimal? {
        didSet {
            if oldValue != budgetTarget {
                budgetHealthResetDate = .now
            }
        }
    }
    /// Optional period (weekly or monthly) the target resets on. Must be set together with
    /// `budgetTarget`; defaults to nil so existing categories round-trip cleanly.
    var budgetPeriod: BudgetPeriod? {
        didSet {
            if oldValue != budgetPeriod {
                budgetHealthResetDate = .now
            }
        }
    }
    /// The instant at which the current budget configuration became the health baseline.
    /// A nil value preserves the original behavior for categories created before budget
    /// editing was introduced. The field is persisted so a relaunch cannot resurrect
    /// health derived from a superseded target or period.
    var budgetHealthResetDate: Date?

    init(
        key: String,
        name: String,
        emoji: String,
        sortOrder: Int = 0,
        logCount: Int = 0,
        budgetTarget: Decimal? = nil,
        budgetPeriod: BudgetPeriod? = nil,
        budgetHealthResetDate: Date? = nil
    ) {
        self.key = key
        self.name = name
        self.emoji = emoji
        self.sortOrder = sortOrder
        self.logCount = logCount
        self.budgetTarget = budgetTarget
        self.budgetPeriod = budgetPeriod
        self.budgetHealthResetDate = budgetHealthResetDate
    }
}

extension SpendCategory {
    /// Key used when nothing else matches (deleted category, malformed input).
    static let fallbackKey = "other"

    /// The basic set seeded on first launch, so a new user isn't staring at an empty
    /// picker. The user can delete all of these and go fully custom.
    /// The basic set seeded on first launch. India-friendly defaults — the user can
    /// delete all of these and go fully custom.
    static let defaultSeeds: [(key: String, name: String, emoji: String)] = [
        ("chai", "Chai", "☕️"),
        ("food", "Food", "🍽️"),
        ("transport", "Transport", "🚌"),
        ("metro", "Metro", "🚇"),
        ("lunch", "Lunch", "🍱"),
        ("groceries", "Groceries", "🛒"),
        ("shopping", "Shopping", "🛍️"),
        ("bills", "Bills", "🧾"),
        ("snacks", "Snacks", "🍿"),
        ("health", "Health", "💊"),
        ("fun", "Fun", "🎉"),
        ("rent", "Rent", "🏠"),
        ("other", "Other", "📦"),
    ]

    /// Builds a unique slug key for a new custom category. `takenKeys` must include
    /// keys still referenced by entries — otherwise recreating a deleted category
    /// name would silently reattach that history to the new category.
    static func makeKey(forName name: String, existing: [SpendCategory], takenKeys: Set<String> = []) -> String {
        let base = name
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == " " }
            .replacingOccurrences(of: " ", with: "-")
        let stem = base.isEmpty ? "custom" : base
        var key = stem
        var counter = 2
        while existing.contains(where: { $0.key == key }) || takenKeys.contains(key) {
            key = "\(stem)-\(counter)"
            counter += 1
        }
        return key
    }
}

/// Fast name/emoji resolution for a snapshot of categories. Build once per view
/// (e.g. from a `@Query`) and pass down; entries whose category was deleted fall
/// back to "Other" instead of crashing.
struct CategoryLookup {
    private let byKey: [String: SpendCategory]

    init(_ categories: [SpendCategory]) {
        var dict: [String: SpendCategory] = [:]
        for category in categories {
            dict[category.key] = category
        }
        byKey = dict
    }

    func category(for key: String) -> SpendCategory? {
        byKey[key]
    }

    func name(for key: String) -> String {
        byKey[key]?.name ?? "Other"
    }

    func emoji(for key: String) -> String {
        byKey[key]?.emoji ?? "🏷️"
    }
}
