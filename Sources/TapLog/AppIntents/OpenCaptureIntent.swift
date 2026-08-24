import AppIntents
import Foundation

// MARK: - Activation Result

/// Unambiguous result of consuming a pending capture activation.
/// `.none` means no intent was pending; `.open` means an OpenCaptureIntent
/// fired and the UI should route to the capture screen.
enum PendingCaptureActivation {
    case none
    case open(prefill: CapturePrefill?)
}

// MARK: - OpenCaptureIntent

/// Opens TapLog directly into the focused expense-capture screen. Designed for the
/// Action Button, Control Center, Siri phrases ("Log an expense in TapLog"), and
/// Shortcuts — zero configuration required.
///
/// Persists a pending activation via `UserDefaults` (App Group suite) so the UI
/// can consume it deterministically on the next launch. Optional prefill parameters
/// (amount, category, note) are carried in the same payload. A parameterless
/// invocation bypasses onboarding, skips the splash, and focuses the amount field.
struct OpenCaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Expense Capture"
    static var description = IntentDescription(
        "Opens TapLog directly into the focused expense capture screen."
    )
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = true

    @Parameter(title: "Amount")
    var amount: Double?

    @Parameter(title: "Category")
    var category: String?

    @Parameter(title: "Note")
    var note: String?

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let pendingActive = "intent.pendingCaptureActive"
        static let pendingAmount = "intent.pendingCaptureAmount"
        static let pendingCategory = "intent.pendingCaptureCategory"
        static let pendingNote = "intent.pendingCaptureNote"
    }

    // MARK: - Write Helpers (static, usable from tests)

    /// Writes a pending capture activation to UserDefaults.
    static func writePendingActivation(
        amount: String? = nil,
        category: String? = nil,
        note: String? = nil,
        defaults: UserDefaults = StoreLocator.sharedDefaults
    ) {
        defaults.set(amount, forKey: Keys.pendingAmount)
        defaults.set(category, forKey: Keys.pendingCategory)
        defaults.set(note, forKey: Keys.pendingNote)
        defaults.set(true, forKey: Keys.pendingActive)
    }

    /// Reads and clears the pending activation. Returns `.none` if nothing is
    /// pending, `.open(prefill:)` if an activation was found (prefill may be nil
    /// for a parameterless invocation).
    static func consumePendingActivation(
        defaults: UserDefaults = StoreLocator.sharedDefaults
    ) -> PendingCaptureActivation {
        guard defaults.bool(forKey: Keys.pendingActive) else { return .none }
        // Clear immediately to prevent double-consumption.
        defaults.set(false, forKey: Keys.pendingActive)

        let amountText = defaults.string(forKey: Keys.pendingAmount)
        let categoryQuery = defaults.string(forKey: Keys.pendingCategory)
        let noteText = defaults.string(forKey: Keys.pendingNote)

        // Clean up payload keys.
        defaults.removeObject(forKey: Keys.pendingAmount)
        defaults.removeObject(forKey: Keys.pendingCategory)
        defaults.removeObject(forKey: Keys.pendingNote)

        let hasContent = amountText != nil || categoryQuery != nil || noteText != nil
        if hasContent {
            return .open(prefill: CapturePrefill(
                amountText: amountText,
                categoryQuery: categoryQuery,
                note: noteText
            ))
        }
        // Parameterless invocation — still .open, but with nil prefill.
        return .open(prefill: nil)
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        var prefillAmount: String? = nil
        var prefillCategory: String? = nil
        let prefillNote: String? = note

        if let amount, amount > 0 {
            prefillAmount = String(amount)
        }
        if let category, !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prefillCategory = category
        }

        await MainActor.run {
            Self.writePendingActivation(
                amount: prefillAmount,
                category: prefillCategory,
                note: prefillNote
            )
        }

        return .result()
    }
}
