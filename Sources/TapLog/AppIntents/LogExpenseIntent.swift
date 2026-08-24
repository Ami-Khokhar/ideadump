import AppIntents
import Foundation
import SwiftData

/// Validation errors thrown by capture intents are surfaced by Siri, Shortcuts,
/// and the widget as a failed action instead of an apparent successful log.
enum TapLogIntentError: LocalizedError {
    case invalidAmount
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "Enter an amount greater than zero and no more than 999,999,999.99."
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

/// The "Log Expense" action exposed to Siri and Shortcuts. The Action Button (M2/M6)
/// points at a Shortcut that calls this.
struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Expense"
    static var description = IntentDescription("Logs a purchase to TapLog.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Note")
    var note: String?

    @Parameter(title: "Category")
    var category: String?

    @MainActor
    func perform() async throws -> some IntentResult {
        let validatedAmount = try TapLogIntentAmountValidator.validate(amount)
        let container = StoreLocator.makeContainer()
        let context = container.mainContext
        let categories = (try? context.fetch(FetchDescriptor<SpendCategory>())) ?? []

        let categoryKey: String
        if let raw = category?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            let lower = raw.lowercased()
            categoryKey = categories.first {
                $0.key.lowercased() == lower || $0.name.lowercased() == lower
            }?.key ?? categories.first?.key ?? SpendCategory.fallbackKey
        } else {
            categoryKey = categories.first?.key ?? SpendCategory.fallbackKey
        }

        let entry = Entry(amount: validatedAmount, category: categoryKey, note: note)
        context.insert(entry)
        do {
            try context.save()
        } catch {
            print("TapLog: Failed to save entry from Siri: \(error)")
            throw TapLogIntentError.saveFailed
        }

        // Same bookkeeping as the home screen: category learning, log totals, streaks.
        CaptureBookkeeping.apply(modelContext: context, categories: categories, categoryKey: categoryKey)
        return .result()
    }
}
