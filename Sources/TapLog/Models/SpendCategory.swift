import Foundation

/// Fixed category list for the prototype. Custom categories arrive in a later milestone.
struct SpendCategory: Identifiable, Hashable {
    let key: String
    let name: String
    let emoji: String

    var id: String { key }

    static let all: [SpendCategory] = [
        SpendCategory(key: "coffee", name: "Coffee", emoji: "☕️"),
        SpendCategory(key: "food", name: "Food", emoji: "🍽️"),
        SpendCategory(key: "transport", name: "Transport", emoji: "🚌"),
        SpendCategory(key: "shopping", name: "Shopping", emoji: "🛍️"),
        SpendCategory(key: "bills", name: "Bills", emoji: "🧾"),
        SpendCategory(key: "fun", name: "Fun", emoji: "🎉"),
        SpendCategory(key: "health", name: "Health", emoji: "💊"),
        SpendCategory(key: "other", name: "Other", emoji: "📦"),
    ]

    static let defaultKey = "coffee"

    static func category(for key: String) -> SpendCategory {
        all.first { $0.key == key }
            ?? all.first { $0.key == defaultKey }
            ?? all[0]
    }

    static func name(for key: String) -> String { category(for: key).name }
    static func emoji(for key: String) -> String { category(for: key).emoji }
}
