import AppIntents
import SwiftUI

/// Prebuilt App Shortcuts for TapLog. These appear in Siri suggestions, the
/// Shortcuts app, and Spotlight — zero user configuration required.
///
/// Two shortcuts are exposed:
/// 1. **Open Expense Capture** — opens the app into the focused capture screen
///    (Action Button, keypad Siri phrase, Control Center). No parameters required.
/// 2. **Log Expense** — headless voice logging via the real `LogExpenseIntent`.
///    The amount parameter (`Double`) cannot appear in `AppShortcut` phrases
///    (the metadata processor only allows `AppEntity`/`AppEnum`), so the phrases
///    omit it. Siri resolves the required amount through standard parameter
///    collection — it will ask "How much?" before running the intent.
struct TapLogShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // MARK: - Open Expense Capture (primary keypad route)

        AppShortcut(
            intent: OpenCaptureIntent(),
            phrases: [
                "Open capture in \(.applicationName)",
                "Open the keypad in \(.applicationName)",
                "Start logging in \(.applicationName)",
            ],
            shortTitle: "Open Expense Capture",
            systemImageName: "plus.circle.fill"
        )

        // MARK: - Log Expense (secondary — headless voice logging)

        // The phrases intentionally omit the $amount parameter. AppShortcuts
        // metadata only allows AppEntity/AppEnum types in phrase interpolation,
        // and Double is rejected. When the user says one of these phrases, Siri
        // matches the intent and then resolves the required `amount` parameter
        // through its standard parameter-collection flow ("How much?").
        // LogExpenseIntent.openAppWhenRun = false, so it logs silently.
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Log an expense in \(.applicationName)",
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
