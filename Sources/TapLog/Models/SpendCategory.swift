import Foundation
import SwiftData

/// A user-managed spending category. Entries reference categories by their stable
/// `key` string, so renaming or deleting a category never breaks an entry — display
/// simply falls back to "Other".
@Model
final class SpendCategory {
    var key: String
    var name: String
    var emoji: String
    var sortOrder: Int

    init(key: String, name: String, emoji: String, sortOrder: Int = 0) {
        self.key = key
        self.name = name
        self.emoji = emoji
        self.sortOrder = sortOrder
    }
}

extension SpendCategory {
    /// Key used when nothing else matches (deleted category, malformed input).
    static let fallbackKey = "other"

    /// The basic set seeded on first launch, so a new user isn't staring at an empty
    /// picker. The user can delete all of these and go fully custom.
    static let defaultSeeds: [(key: String, name: String, emoji: String)] = [
        ("food", "Food", "🍽️"),
        ("transport", "Transport", "🚌"),
        ("rent", "Rent", "🏠"),
        ("coffee", "Coffee", "☕️"),
        ("shopping", "Shopping", "🛍️"),
        ("bills", "Bills", "🧾"),
        ("fun", "Fun", "🎉"),
        ("health", "Health", "💊"),
        ("other", "Other", "📦"),
    ]

    /// Builds a unique slug key for a new custom category.
    static func makeKey(forName name: String, existing: [SpendCategory]) -> String {
        let base = name
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == " " }
            .replacingOccurrences(of: " ", with: "-")
        let stem = base.isEmpty ? "custom" : base
        var key = stem
        var counter = 2
        while existing.contains(where: { $0.key == key }) {
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
