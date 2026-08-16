import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            EntryListView()
                .tabItem { Label("Logs", systemImage: "list.bullet") }
            WeeklyRecapView()
                .tabItem { Label("Recap", systemImage: "chart.bar") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(StoreLocator.makeContainer())
        .environmentObject(UndoStack())
}
