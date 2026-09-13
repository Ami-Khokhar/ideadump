import Foundation

/// Values that pre-fill the capture form when the app is opened via a deep link
/// like `taplog://log?amount=12.50&note=coffee&category=Coffee`.
/// The category is kept as raw text and resolved against the user's category list
/// by the form, so it also matches custom categories.
struct CapturePrefill: Equatable {
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

        amountText = Self.machineAmount(value("amount"))
        note = value("note")
        categoryQuery = value("category")
    }

    /// Validates an amount that arrived in a URL, returning nil for anything the
    /// app would not accept.
    ///
    /// This deliberately does not reuse `Money.parse`. That function exists to
    /// read what a *person* typed, so it resolves the "." in "12.345" the only
    /// way that makes sense for human input — as a grouping mark, giving twelve
    /// thousand. A URL parameter is machine-supplied and has exactly one
    /// meaning, so applying the human heuristic to it turned
    /// `taplog://log?amount=12.345` into a logged ₹12,345.00 and
    /// `amount=0.001` into ₹1.00: silent thousand-fold errors in a spending
    /// number, from a link the widget and the Control Center control both use.
    ///
    /// So the grammar here is strict and unambiguous: digits, at most one dot,
    /// at most two decimal places, within the app's own limit. No grouping
    /// separators — a caller that means twelve hundred writes "1200.00", never
    /// "1,200.00". Anything else pre-fills nothing rather than pre-filling a
    /// number nobody asked for.
    static func machineAmount(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }
        guard let integer = parts.first, !integer.isEmpty,
              integer.allSatisfy(\.isASCII), integer.allSatisfy(\.isNumber) else { return nil }
        if parts.count == 2 {
            let fraction = parts[1]
            guard !fraction.isEmpty, fraction.count <= 2,
                  fraction.allSatisfy(\.isASCII), fraction.allSatisfy(\.isNumber) else { return nil }
        }

        guard let amount = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")),
              amount > 0, amount <= Money.maxAmount else {
            return nil
        }
        return text
    }
}
