import SwiftUI
import SwiftData
import WidgetKit

/// The settings sheet — reached from the home screen's menu. Currency and appearance
/// are stored in the shared App Group defaults so the widget and share extension
/// respect the same choices.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(RetentionManager.self) private var retention

    @AppStorage("currencyCode", store: Money.sharedDefaults)
    private var currencyCode = Locale.current.currency?.identifier ?? "USD"

    @AppStorage("appearanceMode") private var appearanceMode = "system"

#if DEBUG
    @AppStorage("isProDemo") private var isPro = false
#endif

    @State private var showingClearConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(Money.supportedCurrencies, id: \.code) { currency in
                            Text("\(currency.symbol)  \(currency.name)").tag(currency.code)
                        }
                    }
                } header: {
                    Text("Currency")
                } footer: {
                    Text("Used everywhere — the app, the widget, and exports.")
                }

                Section {
                    Picker("Appearance", selection: $appearanceMode) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Overrides the system setting. \"System\" follows your iPhone.")
                }

                Section {
                    Stepper(
                        "Log target: \(retention.weeklyTarget) days/week",
                        value: Binding(
                            get: { retention.weeklyTarget },
                            set: { retention.weeklyTarget = $0 }
                        ),
                        in: 3...7
                    )
                } header: {
                    Text("Consistency")
                } footer: {
                    Text("How many days per week you aim to log. The weekly ring and streak track this target.")
                }

#if DEBUG
                Section("Debug") {
                    Button("Seed sample data") {
                        DebugSeeder.seed(context: modelContext)
                    }
                }
#endif

                Section {
                    Button("Delete all entries", role: .destructive) {
                        showingClearConfirmation = true
                    }
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("This permanently removes your history and resets your consistency progress.")
                }

#if DEBUG
                Section("Preview build") {
                    Button(isPro ? "Turn Pro off (demo)" : "Turn Pro on (demo)") {
                        isPro.toggle()
                    }
                }
#endif
            }
            .scrollContentBackground(.hidden)
            .floatingToolbarScrollEdge()
            .background(Theme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                "Delete all entries?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) {
                    clearAllEntries()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes your history and resets your consistency progress.")
            }
        }
        .tint(Theme.accent)
    }

    /// A wiped history is a clean slate: entries go, and so do the counters,
    /// streaks, and category usage that described them (the weekly-target
    /// preference stays).
    private func clearAllEntries() {
        let all = (try? modelContext.fetch(FetchDescriptor<Entry>())) ?? []
        for entry in all {
            modelContext.delete(entry)
        }
        do {
            try modelContext.save()
        } catch {
            print("TapLog: Failed to clear entries: \(error)")
            return
        }
        CaptureBookkeeping.resetCategoryUsage(modelContext: modelContext)
        StoreLocator.sharedDefaults.removeObject(forKey: "logsLogged")
        retention.resetAll()
        WidgetCenter.shared.reloadTimelines(ofKind: "SpendWidget")
    }
}
