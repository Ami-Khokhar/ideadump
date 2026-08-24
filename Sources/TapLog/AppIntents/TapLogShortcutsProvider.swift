import AppIntents
import SwiftUI

/// Parameterless wrapper around `LogExpenseIntent` that opens the app for the
/// user to complete the amount via Siri voice or the capture screen. This is
/// needed because the AppShortcuts metadata processor only allows `AppEntity`
/// and `AppEnum` types in phrase parameters — `Double` and `String` are both
/// rejected.
struct LogExpenseShortcutIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Expense"
    static var description = IntentDescription(
        "Opens TapLog to log a new expense. Siri will ask for the amount."
    )
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Route to the capture screen — the user completes the log manually.
        OpenCaptureIntent.writePendingActivation()
        return .result()
    }
}

/// Prebuilt App Shortcuts for TapLog. These appear in Siri suggestions, the
/// Shortcuts app, and Spotlight — zero user configuration required.
struct TapLogShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // MARK: - Open Capture (primary — Action Button, Siri, Control Center)

        AppShortcut(
            intent: OpenCaptureIntent(),
            phrases: [
                "Log an expense in \(.applicationName)",
                "Open capture in \(.applicationName)",
                "Record spending in \(.applicationName)",
                "Start logging in \(.applicationName)",
            ],
            shortTitle: "Open Capture",
            systemImageName: "plus.circle.fill"
        )

        // MARK: - Log Expense (secondary — Siri voice logging)

        AppShortcut(
            intent: LogExpenseShortcutIntent(),
            phrases: [
                "Log a purchase in \(.applicationName)",
                "Record an expense in \(.applicationName)",
                "Add spending in \(.applicationName)",
            ],
            shortTitle: "Log Expense",
            systemImageName: "creditcard.fill"
        )
    }

    /// Tile colour shown in Siri suggestions and Shortcuts gallery.
    static var shortcutTileColor: ShortcutTileColor {
        .navy
    }
}
