import SwiftUI
import SwiftData
import UserNotifications

@main
struct TapLogApp: App {
    @StateObject private var undoStack = UndoStack()
    @State private var retention = RetentionManager()
    private let container: ModelContainer

    init() {
        let container = StoreLocator.makeContainer()
        self.container = container
        // One-time carry-over of streaks/totals from pre-App-Group builds.
        RetentionManager.migrateLegacyStateIfNeeded(target: StoreLocator.sharedDefaults)
        // One-time rescue of "Planned" taps recorded before `Entry.intent` existed.
        Entry.migrateLegacyPlannedMarks(container: container)
        // Seed the default category set on first launch.
        DebugSeeder.seedCategoriesIfNeeded(container: container)
        // Hidden hook for automated testing: `simctl launch ... -seedSampleData`
        DebugSeeder.seedIfRequested(container: container)
        // Registering the delegate is not asking for permission — it only says
        // who handles a tap if the user ever grants it. The ask itself is
        // deliberately nowhere near launch; see `RecapNotificationPolicy`.
        UNUserNotificationCenter.current().delegate = RecapNotifier.shared
        // Starts the entitlement listener before any screen can ask `isPro`, so
        // a paying user never sees a locked screen for the moment it takes
        // StoreKit to answer.
        ProStore.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(undoStack)
                .environment(retention)
        }
        .modelContainer(container)
    }
}
