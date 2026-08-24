import Foundation
import SwiftUI

/// Validates and filters raw text input for amount fields.
///
/// Uses `Money.parse` as the single source of truth for separator semantics (US
/// grouping, European comma-decimal, Indian grouping, simple comma decimal).
/// Distinguishes single-character typing from pasted input via the `current`
/// argument: pastes are validated whole; typed input enforces two-decimal max.
enum AmountInputFilter {

    /// Maximum number of characters allowed in the input field.
    static let maxDisplayLength = 15

    /// Maximum number of fractional (decimal) digits allowed when typing.
    static let maxFractionalDigits = 2

    // MARK: - Input Filtering

    /// Filters raw input, preserving separator semantics consistent with `Money.parse`.
    ///
    /// - **Pasted input** (length grew by >1): validated as a whole via `Money.parse`.
    ///   If it parses, the raw text is accepted as-is (preserving the user's formatting).
    ///   If it doesn't parse, a `.rejected` error is returned (malformed paste).
    /// - **Typed input** (length grew by exactly 1): only valid characters are kept,
    ///   with two-decimal enforcement for the fractional part.
    /// - **Deletion** (length shrank): always accepted.
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

        // Determine whether this is a paste (more than one character added).
        let isPaste = trimmed.count - current.count > 1

        if isPaste {
            return filterPaste(trimmed, current: current)
        } else {
            return filterTyped(trimmed, current: current)
        }
    }

    // MARK: - Paste Handling

    /// Validates pasted input as a whole. Preserves the raw text if it parses
    /// correctly; rejects with an error if it doesn't.
    private static func filterPaste(_ raw: String, current: String) -> FilterResult {
        // Strip currency symbols and whitespace but keep separators.
        let stripped = raw.filter { $0.isNumber || $0 == "." || $0 == "," || $0 == "-" }

        // Too long — reject.
        if stripped.count > maxDisplayLength {
            return .rejected(
                error: "Maximum amount is \(Money.format(Money.maxAmount))."
            )
        }

        // Validate through Money.parse.
        if let amount = Money.parse(stripped) {
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

        // Money.parse rejected it — check if it's oversized (has enough digits).
        if errorMessage(for: stripped) != nil {
            return .rejected(
                error: "Maximum amount is \(Money.format(Money.maxAmount))."
            )
        }

        // Malformed paste that doesn't parse — reject with a generic error.
        return .rejected(error: "Invalid amount format.")
    }

    // MARK: - Typed Input Handling

    /// Filters single-character typed input. Keeps only valid characters and
    /// enforces the two-decimal-digit limit.
    private static func filterTyped(_ raw: String, current: String) -> FilterResult {
        let stripped = raw.filter { $0.isNumber || $0 == "." || $0 == "," || $0 == "-" }

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
                        // Third decimal digit — drop it silently.
                        continue
                    }
                }
                allowed.append(ch)
                continue
            }
            // Skip any other character (currency symbols, spaces, etc.)
        }

        // Final check: reject if the typed result exceeds the max amount.
        // Money.parse returns nil for oversized values, so we detect them by
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
