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

    // MARK: - Input Filtering

    /// Filters raw input for the legacy SwiftUI `onChange` callers. New amount
    /// fields use `filterEdit`, which receives the actual UIKit edit metadata.
    ///
    /// - Parameters:
    ///   - raw: The raw text the user typed or pasted.
    ///   - current: The current (pre-edit) text.
    public static func filter(_ raw: String, current: String) -> FilterResult {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        // Empty is always valid (shows placeholder "0").
        guard !trimmed.isEmpty else {
            return .accepted("")
        }

        // Strip to raw numeric content (digits, separators, leading minus).
        let stripped = trimmed.filter { $0.isNumber || $0 == "." || $0 == "," || $0 == "-" }
        let currentStripped = current.filter { $0.isNumber || $0 == "." || $0 == "," || $0 == "-" }

        // Structural change detection (replaces the old length-growth heuristic):
        // A paste or selection-replacement is any edit where the stripped content
        // changes separator count or total length by more than one — i.e. it's not
        // a simple single-digit append.
        let isPaste: Bool = {
            let strippedDiff = abs(stripped.count - currentStripped.count)
            let currentSeparators = currentStripped.filter { $0 == "." || $0 == "," }.count
            let newSeparators = stripped.filter { $0 == "." || $0 == "," }.count
            let separatorChanged = newSeparators != currentSeparators
            return separatorChanged || strippedDiff > 1
        }()

        if isPaste {
            return filterPaste(stripped)
        } else {
            return filterTyped(stripped, current: currentStripped)
        }
    }

    /// Applies one concrete text-field edit. `replacement` and `range` come
    /// from `UITextFieldDelegate`, so a selection replacement is never guessed
    /// from string lengths (which cannot distinguish typing from paste).
    static func filterEdit(current: String, range: NSRange, replacement: String) -> AmountEditResult {
        let candidate = (current as NSString).replacingCharacters(in: range, with: replacement)
        let isSingleTypedCharacter = range.length == 0 && replacement.count == 1

        if isSingleTypedCharacter {
            return filterTypedEdit(candidate: candidate, current: current, replacement: replacement)
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

    private static func filterTypedEdit(candidate: String, current: String, replacement: String) -> AmountEditResult {
        guard replacement.first?.isNumber == true || replacement == "." || replacement == "," else {
            return AmountEditResult(text: current, error: nil, restoresPrevious: true)
        }

        let strippedCandidate = numericCharacters(in: candidate)
        let strippedCurrent = numericCharacters(in: current)

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

    // MARK: - Paste / Replacement Handling

    /// Validates pasted or replaced input as a whole. Preserves the raw text if
    /// it parses correctly via `Money.parse`; rejects with an error if it doesn't.
    private static func filterPaste(_ stripped: String) -> FilterResult {
        // Too long — reject.
        if stripped.count > maxDisplayLength {
            return .rejected(
                error: "Maximum amount is \(Money.format(Money.maxAmount))."
            )
        }

        // Validate through Money.parse (handles grouping/decimal heuristics).
        if validSeparatorSyntax(stripped), let amount = Money.parse(stripped) {
            if amount < 0 {
                return .rejected(error: "Amount must be positive.")
            }
            if amount > Money.maxAmount {
                return .rejected(
                    error: "Maximum amount is \(Money.format(Money.maxAmount))."
                )
            }
            // Parsed successfully — accept the stripped text (separators preserved).
            return .accepted(stripped)
        }

        // Money.parse rejected it — detect oversized values that have too many digits.
        if errorMessage(for: stripped) != nil {
            return .rejected(
                error: "Maximum amount is \(Money.format(Money.maxAmount))."
            )
        }

        // Malformed paste that doesn't parse — reject.
        return .rejected(error: "Invalid amount format.")
    }

    // MARK: - Typed Input Handling

    /// Filters single-character typed input. Keeps only valid characters and
    /// enforces the two-decimal-digit limit.
    private static func filterTyped(_ stripped: String, current: String) -> FilterResult {
        // Determine the decimal separator used in the current text.
        let currentHasDot = current.contains(".")
        let currentHasComma = current.contains(",")
        let decimalSep: Character? = currentHasDot ? "." : (currentHasComma ? "," : nil)

        var allowed = ""
        var hasSep = false
        var fractionalCount = 0
        var inFractional = false

        for (i, ch) in stripped.enumerated() {
            if ch == "-" && i == 0 {
                allowed.append(ch)
                continue
            }
            if ch == "." || ch == "," {
                // Determine if this separator is the decimal point.
                let isDecimal: Bool
                if let ds = decimalSep {
                    isDecimal = (ch == ds)
                } else {
                    // No existing separator — this is the first one, treat as decimal.
                    isDecimal = true
                }
                if isDecimal {
                    if hasSep { continue } // already have a decimal separator
                    hasSep = true
                    inFractional = true
                    allowed.append(ch)
                } else {
                    // Grouping separator — allow it (Money.parse handles it).
                    allowed.append(ch)
                }
                continue
            }
            if ch.isNumber {
                if inFractional {
                    fractionalCount += 1
                    if fractionalCount > maxFractionalDigits {
                        // Third decimal digit — drop it.
                        continue
                    }
                }
                allowed.append(ch)
                continue
            }
            // Skip any other character (currency symbols, spaces, etc.)
        }

        // Final check: reject if the typed result exceeds the max amount.
        // Money.parse returns nil for oversized values, so detect them by
        // checking if the text is a valid number that's simply too large.
        if Money.parse(allowed) == nil && looksLikeNumeric(allowed) {
            return .rejected(
                error: "Maximum amount is \(Money.format(Money.maxAmount))."
            )
        }

        return .accepted(allowed)
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

// MARK: - Filter Result

enum FilterResult {
    case accepted(String)
    case rejected(error: String)

    var text: String {
        switch self {
        case .accepted(let t): return t
        case .rejected: return ""
        }
    }

    var error: String? {
        switch self {
        case .accepted: return nil
        case .rejected(let e): return e
        }
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
