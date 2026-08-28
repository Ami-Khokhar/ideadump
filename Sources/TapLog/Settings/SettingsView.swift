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

    private var pro = ProStore.shared

    @State private var showingClearConfirmation = false
    @State private var showingFrontDoors = false
    @State private var showingPaywall = false

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

                // Moved here when the home screen's ⋯ menu was cut back to
                // Settings alone. The widget, Lock Screen and Action Button are
                // setup, not navigation — they belong with the other things you
                // configure once, not on a bar meant for daily use.
                Section {
                    Button("Faster ways to log") {
                        showingFrontDoors = true
                    }
                } footer: {
                    Text("Add TapLog to your Home Screen, Lock Screen, Control Centre or Action Button.")
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

                // Only shown when sharing is actually broken. Silence used to be
                // the only signal that the widget and share extension were
                // reading a different store than the app, which surfaces to the
                // user as a widget stuck at zero with no explanation.
                if !StoreLocator.isUsingSharedStore {
                    Section {
                        Label {
                            Text("Widget and Share Sheet can't reach your data")
                                .font(.subheadline.weight(.medium))
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Theme.clay)
                        }
                    } footer: {
                        Text("This build has no App Group entitlement, so TapLog keeps your expenses inside the app. Everything here works — the widget and Share Sheet just won't show them.")
                    }
                }

#if DEBUG
                Section("Debug") {
                    Button("Seed sample data") {
                        DebugSeeder.seed(context: modelContext)
                    }
                }
#endif

                Section {
                    if pro.isPro {
                        Label {
                            Text("TapLog Pro is unlocked")
                        } icon: {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Theme.accent)
                        }
                    } else {
                        Button("TapLog Pro") { showingPaywall = true }
                    }
                    // Always offered, unlocked or not: someone reinstalling on a
                    // new phone arrives here locked out and looking for exactly
                    // this, and hiding it behind the paywall would make them buy
                    // a thing they already own.
                    Button("Restore purchase") {
                        Task { await pro.restore() }
                    }
                    .disabled(pro.isWorking)
                } header: {
                    Text("Pro")
                } footer: {
                    if let failure = pro.failureMessage {
                        Text(failure).foregroundStyle(Theme.clay)
                    } else {
                        Text("One payment unlocks a target for every category and the monthly recap.")
                    }
                }

                Section {
                    Button("Delete all entries", role: .destructive) {
                        showingClearConfirmation = true
                    }
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("This permanently removes your history and resets your consistency progress.")
                }

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
            .sheet(isPresented: $showingPaywall) {
                PaywallView(reason: .secondTree)
                    .tint(Theme.accent)
            }
            .sheet(isPresented: $showingFrontDoors) {
                SetupFrontDoorsView(onDone: { showingFrontDoors = false })
                    .presentationDetents([.medium, .large])
                    .tint(Theme.accent)
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
        // Someone who has just deleted every expense should not be told on
        // Sunday morning that their week is ready.
        RecapNotifier.shared.cancelWeeklyRecap()
        WidgetCenter.shared.reloadTimelines(ofKind: "SpendWidget")
    }
}
