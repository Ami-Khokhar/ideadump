import Foundation

/// Validation errors shared by the app intent and widget extension.
enum TapLogIntentError: LocalizedError {
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
    static func validate(_ amount: Double) throws -> Decimal {
        let maxAmount = NSDecimalNumber(decimal: Money.maxAmount).doubleValue
        guard amount.isFinite, amount > 0, amount <= maxAmount else {
            throw TapLogIntentError.invalidAmount
        }
        return Money.fromAmount(amount)
    }
}
