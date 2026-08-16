import Foundation

enum Money {
    /// Parses user input like "12.50", "12,50", or "$12" into a Decimal.
    static func parse(_ raw: String) -> Decimal? {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "$", with: "")
        cleaned = cleaned.replacingOccurrences(of: "€", with: "")
        cleaned = cleaned.replacingOccurrences(of: "£", with: "")
        cleaned = cleaned.replacingOccurrences(of: "¥", with: "")
        cleaned = cleaned.replacingOccurrences(of: " ", with: "")
        cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Plain decimal string, e.g. "12.5" — used to pre-fill the edit form.
    static func plainString(_ amount: Decimal) -> String {
        NSDecimalNumber(decimal: amount).stringValue
    }

    /// Locale-aware currency display, e.g. "$12.50".
    static func format(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
}
