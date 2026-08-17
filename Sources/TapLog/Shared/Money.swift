import Foundation

enum Money {
    // MARK: - Currency setting (shared with widget + share extension)

    /// Common currencies for the Settings picker. `code` is the ISO 4217 code used by
    /// `formatted(.currency(code:))`; `symbol` is what the capture hero shows.
    static let supportedCurrencies: [(code: String, symbol: String, name: String)] = [
        ("USD", "$", "US Dollar"),
        ("EUR", "€", "Euro"),
        ("GBP", "£", "British Pound"),
        ("JPY", "¥", "Japanese Yen"),
        ("INR", "₹", "Indian Rupee"),
        ("CAD", "$", "Canadian Dollar"),
        ("AUD", "$", "Australian Dollar"),
        ("CHF", "CHF", "Swiss Franc"),
        ("CNY", "¥", "Chinese Yuan"),
        ("SEK", "kr", "Swedish Krona"),
        ("NOK", "kr", "Norwegian Krone"),
        ("KRW", "₩", "South Korean Won"),
        ("BRL", "R$", "Brazilian Real"),
        ("MXN", "$", "Mexican Peso"),
        ("SGD", "$", "Singapore Dollar"),
        ("NZD", "$", "New Zealand Dollar"),
        ("ZAR", "R", "South African Rand"),
    ]

    /// Defaults shared with the widget and share extension, so a currency chosen in
    /// Settings is respected everywhere.
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: StoreLocator.appGroupID)
    }

    /// The user's chosen currency code, falling back to the device locale.
    static var currencyCode: String {
        sharedDefaults?.string(forKey: "currencyCode")
            ?? Locale.current.currency?.identifier
            ?? "USD"
    }

    /// Display symbol for the capture hero ("$", "€", "¥", …).
    static var currencySymbol: String {
        if let match = supportedCurrencies.first(where: { $0.code == currencyCode }) {
            return match.symbol
        }
        return Locale(identifier: currencyCode).currencySymbol ?? "$"
    }

    /// The amount format used everywhere — follows the user's currency setting.
    static func format(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: currencyCode))
    }

    /// Parses user input like "12.50", "12,50", "$1,200", or "1.200,50" into a Decimal.
    ///
    /// Handles both `.` and `,` as decimal *or* grouping separators without assuming a
    /// locale, so a US "1,200" logs as 1200 (not 1.20) and a European "12,50" logs as
    /// 12.50. When both separators are present the rightmost one is the decimal point;
    /// when only one is present it's a decimal point only if it's a single separator with
    /// at most two trailing digits, otherwise it's grouping.
    static func parse(_ raw: String) -> Decimal? {
        // Keep only digits, separators, and a leading sign; drop currency symbols/spaces.
        let stripped = raw.filter { $0.isNumber || $0 == "." || $0 == "," || $0 == "-" }
        guard stripped.contains(where: \.isNumber) else { return nil }

        let hasComma = stripped.contains(",")
        let hasDot = stripped.contains(".")
        let normalized: String

        if hasComma && hasDot {
            // The rightmost separator is the decimal point; the other is grouping.
            let commaIsDecimal = stripped.lastIndex(of: ",")! > stripped.lastIndex(of: ".")!
            let decimalSep: Character = commaIsDecimal ? "," : "."
            let groupingSep: Character = commaIsDecimal ? "." : ","
            normalized = stripped
                .replacingOccurrences(of: String(groupingSep), with: "")
                .replacingOccurrences(of: String(decimalSep), with: ".")
        } else if hasComma || hasDot {
            let sep: Character = hasComma ? "," : "."
            let occurrences = stripped.filter { $0 == sep }.count
            let trailing = stripped.distance(
                from: stripped.lastIndex(of: sep)!, to: stripped.endIndex
            ) - 1
            if occurrences == 1 && trailing <= 2 {
                normalized = stripped.replacingOccurrences(of: String(sep), with: ".") // decimal
            } else {
                normalized = stripped.replacingOccurrences(of: String(sep), with: "") // grouping
            }
        } else {
            normalized = stripped
        }

        guard let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        // Reject absurd amounts (e.g. a pasted phone number) — they'd corrupt totals
        // and are never a real expense.
        guard value >= 0 && value <= maxAmount else { return nil }
        return value
    }

    /// Largest accepted amount. Generous for any real expense; anything above is
    /// almost certainly pasted garbage, not a purchase.
    static let maxAmount: Decimal = 999_999_999.99

    /// Converts an amount that arrived as a `Double` (Siri/Shortcuts/widget intents pass
    /// `Double`) into a Decimal rounded to cents, avoiding binary-float artifacts like
    /// `Decimal(12.99)` = 12.99000000000000199.
    static func fromAmount(_ value: Double) -> Decimal {
        var source = Decimal(value)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 2, .plain)
        return rounded
    }

    /// Plain decimal string, e.g. "12.5" — used to pre-fill the edit form.
    static func plainString(_ amount: Decimal) -> String {
        NSDecimalNumber(decimal: amount).stringValue
    }

}
