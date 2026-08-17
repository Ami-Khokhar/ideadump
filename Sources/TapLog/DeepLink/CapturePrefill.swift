import Foundation

/// Values that pre-fill the capture form when the app is opened via a deep link
/// like `taplog://log?amount=12.50&note=coffee&category=Coffee`.
/// The category is kept as raw text and resolved against the user's category list
/// by the form, so it also matches custom categories.
struct CapturePrefill {
    var amountText: String?
    var categoryQuery: String?
    var note: String?

    init(amountText: String? = nil, categoryQuery: String? = nil, note: String? = nil) {
        self.amountText = amountText
        self.categoryQuery = categoryQuery
        self.note = note
    }

    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "taplog",
              components.host == "log" else {
            return nil
        }
        let items = components.queryItems ?? []

        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }

        amountText = value("amount")
        note = value("note")
        categoryQuery = value("category")
    }
}
