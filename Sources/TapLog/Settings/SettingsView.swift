import SwiftUI
import SwiftData

/// The settings sheet — reached from the home screen's menu. Currency and appearance
/// are stored in the shared App Group defaults so the widget and share extension
/// respect the same choices.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @AppStorage("currencyCode", store: Money.sharedDefaults)
    private var currencyCode = Locale.current.currency?.identifier ?? "USD"

    @AppStorage("appearanceMode") private var appearanceMode = "system"

    @AppStorage("isProDemo") private var isPro = false

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

                Section("Data") {
                    Button("Seed sample data") {
                        DebugSeeder.seed(context: modelContext)
                    }
                    Button("Delete all entries", role: .destructive) {
                        let all = try? modelContext.fetch(FetchDescriptor<Entry>())
                        for entry in all ?? [] {
                            modelContext.delete(entry)
                        }
                        try? modelContext.save()
                    }
                }

                Section("Preview build") {
                    Button(isPro ? "Turn Pro off (demo)" : "Turn Pro on (demo)") {
                        isPro.toggle()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(Theme.accent)
    }
}
