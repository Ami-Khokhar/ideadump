import Foundation

/// Validation errors shared by the app intent and widget extension.
enum TapLogIntentError: LocalizedError, Equatable {
    case invalidAmount
    case invalidOptionalAmount
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "Enter an amount greater than zero and no more than 999,999,999.99."
        case .invalidOptionalAmount:
            return "The optional amount must be greater than zero and no more than 999,999,999.99."
        case .saveFailed:
            return "TapLog could not save that expense. Please try again."
        }
    }
}

enum TapLogIntentAmountValidator {
    /// Validates the amount that will actually be stored, not the one that
    /// arrived.
    ///
    /// Siri, Shortcuts and the widget all hand intents a `Double`, and
    /// `Money.fromAmount` rounds it to cents before it reaches the store.
    /// Checking only the raw value let sub-cent input through: `0.001` clears
    /// `> 0`, then rounds to `0.00` and was saved as a zero-value expense. The
    /// raw guard stays as a cheap filter for NaN, infinity and absurd
    /// magnitudes; the rounded value is what gets the real check.
    static func validate(_ amount: Double) throws -> Decimal {
        let maxAmount = NSDecimalNumber(decimal: Money.maxAmount).doubleValue
        guard amount.isFinite, amount > 0, amount <= maxAmount else {
            throw TapLogIntentError.invalidAmount
        }
        let rounded = Money.fromAmount(amount)
        guard rounded > 0, rounded <= Money.maxAmount else {
            throw TapLogIntentError.invalidAmount
        }
        return rounded
    }

    /// The same check for an optional amount that only pre-fills the keypad.
    /// Nothing is persisted here, but a sub-cent value would still pre-fill a
    /// field the user cannot log from, so it is rejected on the same terms and
    /// the rounded value is what gets pre-filled.
    static func validateOptional(_ amount: Double?) throws -> Decimal? {
        guard let amount else { return nil }
        do {
            return try validate(amount)
        } catch {
            throw TapLogIntentError.invalidOptionalAmount
        }
    }
}
