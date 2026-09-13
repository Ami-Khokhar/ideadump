import AppIntents
import Foundation
import SwiftData

/// The "Log Expense" action exposed to Siri and Shortcuts. It is headless: Siri asks
/// for any missing amount, saves the entry, and returns a spoken confirmation.
struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Expense"
    static var description = IntentDescription("Logs a purchase to TapLog.")
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true

    @Parameter(title: "Amount", requestValueDialog: "How much did you spend?")
    var amount: Double

    /// An entity rather than a String so it can appear in an `AppShortcut` phrase
    /// ("Log chai in TapLog") — phrases only interpolate `AppEntity`/`AppEnum`.
    @Parameter(title: "Category", requestValueDialog: "What category was this expense?")
    var category: CategoryEntity

    @Parameter(title: "Note")
    var note: String?

    /// Siri and Shortcuts never prompt for an optional parameter, so the note is
    /// asked for in `perform()` instead. Users who never add notes can switch the
    /// question off in their own shortcut; a note passed in is never re-asked.
    @Parameter(title: "Ask for Note", default: true)
    var askForNote: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) in \(\.$category)") {
            \.$note
            \.$askForNote
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let validatedAmount: Decimal
        do {
            validatedAmount = try TapLogIntentAmountValidator.validate(amount)
        } catch {
            // Ask again rather than end the shortcut on a typo like "0".
            throw $amount.needsValueError("Enter an amount greater than zero. How much did you spend?")
        }

        var rawNote = note
        if rawNote == nil, askForNote {
            rawNote = try await $note.requestValue("Any note? Say “skip” for none.")
        }
        let cleanedNote = Self.cleanedNote(rawNote)

        // Reuses the process-wide container. Siri runs this intent inside the
        // app's own process, where a container is already open.
        let container = try StoreLocator.container()
        let context = container.mainContext
        let categories = (try? context.fetch(FetchDescriptor<SpendCategory>())) ?? []

        let categoryKey = Self.resolvedKey(entity: category, categories: categories)

        let entry = Entry(amount: validatedAmount, category: categoryKey, note: cleanedNote)
        context.insert(entry)
        do {
            try context.save()
        } catch {
            Log.intents.error("Failed to save entry from Siri: \(Log.describe(error), privacy: .public)")
            throw TapLogIntentError.saveFailed
        }

        // Same bookkeeping as the home screen: category learning, log totals, streaks.
        CaptureBookkeeping.apply(modelContext: context, categories: categories, categoryKey: categoryKey)
        OnboardingFlow.recordIntentUse(OnboardingFlow.logExpenseUsedKey)
        let categoryName = CategoryLookup(categories).name(for: categoryKey)
        return .result(dialog: "Logged \(Money.format(validatedAmount)) in \(categoryName).")
    }

    /// Words that answer the note question with "no note". Siri transcribes a
    /// spoken "skip" as "Skip." — case and trailing punctuation are ignored.
    private static let skipWords: Set<String> = ["skip", "no", "none", "nope", "nothing", "no note"]

    /// Trims the note and turns an empty answer or a skip word into no note.
    static func cleanedNote(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        let word = trimmed.lowercased().trimmingCharacters(in: .punctuationCharacters)
        if word.isEmpty || skipWords.contains(word) { return nil }
        return trimmed
    }

    static func resolvedKey(
        entity: CategoryEntity,
        categories: [SpendCategory]
    ) -> String {
        if categories.contains(where: { $0.key == entity.id }) {
            return entity.id
        }
        return SpendCategory.fallbackKey
    }

    /// String-based resolution for callers that only have text, such as deep
    /// links and older Shortcuts actions.
    static func resolveCategoryKey(_ raw: String?, categories: [SpendCategory]) -> String {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return SpendCategory.fallbackKey
        }
        let lower = raw.lowercased()
        return categories.first {
            $0.key.lowercased() == lower || $0.name.lowercased() == lower
        }?.key ?? SpendCategory.fallbackKey
    }
}
