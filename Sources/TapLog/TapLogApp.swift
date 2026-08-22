import SwiftUI
import SwiftData

@main
struct TapLogApp: App {
    @StateObject private var undoStack = UndoStack()
    @State private var retention = RetentionManager()
    private let container: ModelContainer

    init() {
        let container = StoreLocator.makeContainer()
        self.container = container
        // Seed the default category set on first launch.
        DebugSeeder.seedCategoriesIfNeeded(container: container)
        // Hidden hook for automated testing: `simctl launch ... -seedSampleData`
        DebugSeeder.seedIfRequested(container: container)
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
