import Foundation
import SwiftUI

/// Validates and filters raw text input for amount fields.
///
/// Uses `Money.parse` as the single source of truth for separator semantics (US
/// grouping, European comma-decimal, Indian grouping, simple comma decimal).
///
/// **Detection strategy:** we never infer paste-vs-type from total string-length
/// growth alone (that breaks when selected text is replaced with a similarly-sized
/// paste). Instead we check structural change: if the *stripped* input (digits +
/// separators only) differs in separator count or overall length from the current
/// text, it is treated as a paste/replacement and validated as a whole via
/// `Money.parse`. Only a pure single-digit append (no new separators, length +1)
/// takes the lightweight typed-input path with two-decimal enforcement.
enum AmountInputFilter {

    /// Maximum number of characters allowed in the input field.
    static let maxDisplayLength = 15

    /// Maximum number of fractional (decimal) digits allowed when typing.
    static let maxFractionalDigits = 2

    /// The mark this locale uses as a decimal point, as opposed to a grouping
    /// separator. Read through a parameter rather than inline so the rules below
    /// can be tested without depending on the machine running them: "." is the
    /// decimal in en_US and the *grouping* mark in de_DE, and the two cases have
    /// opposite answers.
    static var localeDecimalSeparator: Character {
        Locale.current.decimalSeparator?.first ?? "."
    }

    /// Applies one concrete text-field edit. `replacement` and `range` come
    /// from `UITextFieldDelegate`, so a selection replacement is never guessed
    /// from string lengths (which cannot distinguish typing from paste).
    static func filterEdit(
        current: String,
        range: NSRange,
        replacement: String,
        decimalSeparator: Character = localeDecimalSeparator
    ) -> AmountEditResult {
        let candidate = (current as NSString).replacingCharacters(in: range, with: replacement)
        let isSingleTypedCharacter = range.length == 0 && replacement.count == 1

        if isSingleTypedCharacter {
            return filterTypedEdit(
                candidate: candidate,
                current: current,
                replacement: replacement,
                decimalSeparator: decimalSeparator
            )
        }

        // Deletion should remain fluid even if it temporarily leaves an
        // incomplete value such as "12.". Final validity is checked when the
        // user taps Log; showing an error while they are correcting the value
        // makes the field feel as though it stopped accepting input.
        if replacement.isEmpty {
            return AmountEditResult(
                text: numericCharacters(in: candidate),
                error: nil,
                restoresPrevious: false
            )
        }

        return filterWholeEdit(candidate)
    }

    private static func filterTypedEdit(
        candidate: String,
        current: String,
        replacement: String,
        decimalSeparator: Character
    ) -> AmountEditResult {
        guard replacement.first?.isNumber == true || replacement == "." || replacement == "," else {
            return AmountEditResult(text: current, error: nil, restoresPrevious: true)
        }

        let strippedCandidate = strippingLeadingZeros(numericCharacters(in: candidate))
        let strippedCurrent = numericCharacters(in: current)

        // A number has one decimal point. The first one typed is allowed through
        // below; every one after it is rejected here, so "15.5.2.275.57" can no
        // longer be built one key at a time — which is exactly what the keypad
        // let you do, because the guard underneath only ever caught a *different*
        // separator arriving second.
        //
        // Deliberately scoped to the decimal mark alone. The other separator is
        // grouping, and "1,20,000" is still typed one comma at a time.
        if let typed = replacement.first,
           typed == decimalSeparator,
           strippedCurrent.contains(decimalSeparator) {
            return AmountEditResult(text: current, error: nil, restoresPrevious: true)
        }

        // Once a single separator is being used as a decimal, a second,
        // different separator is malformed interactive input (e.g. 1.2,).
        if (replacement == "." || replacement == ","),
           let first = strippedCurrent.first(where: { $0 == "." || $0 == "," }),
           strippedCurrent.filter({ $0 == "." || $0 == "," }).count == 1,
           first != replacement.first,
           fractionalDigits(in: strippedCurrent, separator: first) <= maxFractionalDigits {
            return AmountEditResult(text: current, error: "Invalid amount format.", restoresPrevious: true)
        }

        // A third fractional digit is a typing error; leave the previous text
        // in place. This is handled before whole-value parsing so grouping such
        // as 1,20,000 can still be entered one character at a time.
        let currentSeparators = strippedCurrent.filter { $0 == "." || $0 == "," }
        if currentSeparators.count == 1,
           let decimal = currentSeparators.first,
           fractionalDigits(in: strippedCurrent, separator: decimal) <= maxFractionalDigits,
           fractionalDigits(in: strippedCandidate, separator: decimal) > maxFractionalDigits {
            return AmountEditResult(text: current, error: nil, restoresPrevious: true)
        }

        if exceedsMaximum(strippedCandidate) {
            return AmountEditResult(
                text: current,
                error: nil,
                restoresPrevious: true
            )
        }

        return AmountEditResult(text: strippedCandidate, error: nil, restoresPrevious: false)
    }

    private static func filterWholeEdit(_ candidate: String) -> AmountEditResult {
        let stripped = numericCharacters(in: candidate)
        if candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return AmountEditResult(text: "", error: nil, restoresPrevious: false)
        }
        guard !stripped.isEmpty else {
            return AmountEditResult(text: candidate, error: "Invalid amount format.", restoresPrevious: false)
        }

        guard stripped.count <= maxDisplayLength else {
            return AmountEditResult(text: stripped, error: maximumError, restoresPrevious: false)
        }

        if exceedsMaximum(stripped) {
            return AmountEditResult(text: stripped, error: maximumError, restoresPrevious: false)
        }

        guard validSeparatorSyntax(stripped), let amount = Money.parse(stripped) else {
            return AmountEditResult(text: stripped, error: "Invalid amount format.", restoresPrevious: false)
        }
        guard amount <= Money.maxAmount else {
            return AmountEditResult(text: stripped, error: maximumError, restoresPrevious: false)
        }
        return AmountEditResult(text: stripped, error: nil, restoresPrevious: false)
    }

    private static var maximumError: String {
        "Maximum amount is \(Money.format(Money.maxAmount))."
    }

    private static func numericCharacters(in value: String) -> String {
        value.filter { $0.isNumber || $0 == "." || $0 == "," || $0 == "-" }
    }

    /// Drops leading zeros from the integer part, so tapping 0-2-5 reads as 25
    /// rather than 025. Money is never written with them, and an amount padded
    /// out with zeros looks like a reference number rather than a price.
    ///
    /// A single 0 survives, because it is the first keystroke of 0.50. Only the
    /// integer part is touched — the fraction keeps every zero it was given, and
    /// so does a value that merely *contains* a zero, like 100.
    static func strippingLeadingZeros(_ value: String) -> String {
        guard value.first == "0" else { return value }
        let integerEnd = value.firstIndex { $0 == "." || $0 == "," } ?? value.endIndex
        let trimmed = value[..<integerEnd].drop { $0 == "0" }
        return (trimmed.isEmpty ? "0" : String(trimmed)) + value[integerEnd...]
    }

    private static func fractionalDigits(in value: String, separator: Character) -> Int {
        guard let index = value.lastIndex(of: separator) else { return 0 }
        return value.distance(from: index, to: value.endIndex) - 1
    }

    private static func exceedsMaximum(_ value: String) -> Bool {
        guard let normalized = normalizedDecimalString(value),
              let decimal = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else {
            return false
        }
        return decimal > Money.maxAmount
    }

    /// Validates grouping placement in complete replacements before delegating
    /// numeric conversion to `Money.parse`.
    private static func validSeparatorSyntax(_ value: String) -> Bool {
        let unsigned = value.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let hasComma = unsigned.contains(",")
        let hasDot = unsigned.contains(".")
        guard hasComma || hasDot else { return unsigned.allSatisfy(\.isNumber) }

        if hasComma && hasDot {
            let decimal: Character = unsigned.lastIndex(of: ",")! > unsigned.lastIndex(of: ".")! ? "," : "."
            let grouping: Character = decimal == "," ? "." : ","
            guard let decimalIndex = unsigned.lastIndex(of: decimal) else { return false }
            let fractional = String(unsigned[unsigned.index(after: decimalIndex)...])
            guard !fractional.isEmpty,
                  fractional.count <= maxFractionalDigits,
                  fractional.allSatisfy({ $0.isNumber }) else { return false }
            let integer = String(unsigned[..<decimalIndex])
            return validGrouping(integer, separator: grouping)
        }

        let separator: Character = hasComma ? "," : "."
        let parts = unsigned.split(separator: separator, omittingEmptySubsequences: false).map(String.init)
        guard parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else { return false }
        if parts.count == 2 && parts[1].count <= maxFractionalDigits { return true }
        return validGrouping(unsigned, separator: separator)
    }

    private static func validGrouping(_ value: String, separator: Character) -> Bool {
        let parts = value.split(separator: separator).map(String.init)
        guard parts.count > 1, parts[0].count >= 1, parts[0].count <= 3 else { return false }
        guard parts.dropFirst().last?.count == 3 else { return false }
        return parts.dropFirst().allSatisfy { $0.count == 3 || $0.count == 2 }
    }

    private static func normalizedDecimalString(_ value: String) -> String? {
        let stripped = numericCharacters(in: value)
        let hasComma = stripped.contains(",")
        let hasDot = stripped.contains(".")
        if hasComma && hasDot {
            let decimal: Character = stripped.lastIndex(of: ",")! > stripped.lastIndex(of: ".")! ? "," : "."
            let grouping: Character = decimal == "," ? "." : ","
            return stripped.replacingOccurrences(of: String(grouping), with: "")
                .replacingOccurrences(of: String(decimal), with: ".")
        }
        let separator: Character?
        if hasComma { separator = "," }
        else if hasDot { separator = "." }
        else { separator = nil }
        guard let separator else { return stripped }
        let trailing = fractionalDigits(in: stripped, separator: separator)
        let occurrences = stripped.filter { $0 == separator }.count
        if occurrences == 1 && trailing <= maxFractionalDigits {
            return stripped.replacingOccurrences(of: String(separator), with: ".")
        }
        return stripped.replacingOccurrences(of: String(separator), with: "")
    }

    /// Returns true if the string contains at least one digit and only
    /// valid numeric characters (digits, separators, optional leading minus).
    private static func looksLikeNumeric(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        return s.allSatisfy { $0.isNumber || $0 == "." || $0 == "," || ($0 == "-" && s.first == $0) }
    }

    // MARK: - Amount Validation

    /// Checks whether the current text represents a valid, loggable amount.
    static func isValid(_ text: String) -> Bool {
        guard let amount = Money.parse(text), amount > 0 else { return false }
        return amount <= Money.maxAmount
    }

    /// Returns the parsed Decimal if valid, nil otherwise.
    static func parsedAmount(_ text: String) -> Decimal? {
        guard let amount = Money.parse(text), amount > 0 else { return nil }
        return amount <= Money.maxAmount ? amount : nil
    }

    /// Error message for oversized values, or nil if valid/empty.
    /// Checks the raw numeric string independently of `Money.parse` (which
    /// silently rejects oversized values and returns nil).
    static func errorMessage(for text: String) -> String? {
        let stripped = text.filter { $0.isNumber || $0 == "." || $0 == "," }
        guard !stripped.isEmpty else { return nil }

        // If Money.parse accepted it and it's positive, it's valid.
        if let amount = Money.parse(text), amount > 0 {
            return nil
        }

        // Count integer digits (excluding separators).
        let intDigits = stripped.filter(\.isNumber).count
        let hasFractional = stripped.contains(".") || stripped.contains(",")
        let integerDigitCount: Int
        if hasFractional {
            let sep: Character = stripped.contains(".") ? "." : ","
            integerDigitCount = stripped.split(separator: sep, maxSplits: 1)
                .first?.filter(\.isNumber).count ?? 0
        } else {
            integerDigitCount = intDigits
        }
        if integerDigitCount > 9 {
            return "Maximum amount is \(Money.format(Money.maxAmount))."
        }
        return nil
    }
}

/// Result of an edit for the UIKit-backed amount field. `text` is retained for
/// rejected paste/replacement edits so malformed input remains visible and can
/// be corrected; `restoresPrevious` is reserved for a rejected typed character.
struct AmountEditResult {
    let text: String
    let error: String?
    let restoresPrevious: Bool
}
