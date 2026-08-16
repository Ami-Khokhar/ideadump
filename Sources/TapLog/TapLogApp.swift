import SwiftUI
import SwiftData

@main
struct TapLogApp: App {
    @StateObject private var undoStack = UndoStack()
    private let container: ModelContainer

    init() {
        let container = StoreLocator.makeContainer()
        self.container = container
        // Hidden hook for automated testing: `simctl launch ... -seedSampleData`
        DebugSeeder.seedIfRequested(container: container)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(undoStack)
        }
        .modelContainer(container)
    }
}
