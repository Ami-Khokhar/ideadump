import Foundation

/// Values that pre-fill the capture form when the app is opened via a deep link
/// like `taplog://log?amount=12.50&note=coffee&category=Coffee`.
struct CapturePrefill {
    var amountText: String?
    var categoryKey: String?
    var note: String?

    init(amountText: String? = nil, categoryKey: String? = nil, note: String? = nil) {
        self.amountText = amountText
        self.categoryKey = categoryKey
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

        if let raw = value("category"), !raw.isEmpty {
            let lower = raw.lowercased()
            categoryKey = SpendCategory.all.first {
                $0.key == lower || $0.name.lowercased() == lower
            }?.key
        }
    }
}
