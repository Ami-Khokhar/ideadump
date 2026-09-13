import AppIntents
import SwiftUI

/// Prebuilt App Shortcuts for TapLog. These appear in Siri suggestions, the
/// Shortcuts app, and Spotlight — zero user configuration required.
///
/// Two shortcuts are exposed:
/// 1. **Log Expense** — headless voice logging via the real `LogExpenseIntent`.
/// 2. **Open Expense Capture** — opens the app into the focused capture screen
///    (keypad Siri phrase, Control Center). No parameters required.
///    The amount parameter (`Double`) cannot appear in `AppShortcut` phrases
///    (the metadata processor only allows `AppEntity`/`AppEnum`), so the phrases
///    omit it. Siri resolves the required amount through standard parameter
///    collection — it will ask "How much?" before running the intent.
struct TapLogShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // MARK: - Log Expense (primary — headless voice logging)

        // The amount can never appear in a phrase: AppShortcuts metadata only
        // allows AppEntity/AppEnum types in phrase interpolation, and Double is
        // rejected outright. So "log 40 on chai" is not expressible as a
        // registered phrase, however it is written.
        //
        // The *category* is expressible, because `CategoryEntity` is an AppEntity.
        // The category-carrying phrases come first so Siri prefers them when a
        // category is spoken. Otherwise Siri collects the required amount and
        // category in that order using the intent's request dialogs, then the
        // intent asks for an optional note.
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Log \(\.$category) in \(.applicationName)",
                "Log a \(\.$category) expense in \(.applicationName)",
                "Add \(\.$category) spending in \(.applicationName)",
                "Log an expense in \(.applicationName)",
                "Log a purchase in \(.applicationName)",
                "Record an expense in \(.applicationName)",
                "Add spending in \(.applicationName)",
            ],
            shortTitle: "Log Expense",
            systemImageName: "creditcard.fill"
        )

        // MARK: - Open Expense Capture (keypad route)

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
    }

    /// Tile colour shown in Siri suggestions and Shortcuts gallery.
    static var shortcutTileColor: ShortcutTileColor {
        .navy
    }
}
