import SwiftUI
import SwiftData

/// App root: a single capture-first home screen. Everything else — History, Recap,
/// front doors, Settings — lives behind the dropdown menu so the home page stays a
/// pure logging surface. Also hosts the first-session onboarding state machine,
/// deep-link prefill, appearance override, and the app-wide undo toast.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var undoStack: UndoStack

    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @AppStorage("onboardingActive") private var onboardingActive = false
    @AppStorage("onboardingStepRaw") private var onboardingStepRaw = OnboardingStep.capture.rawValue
    @AppStorage("appearanceMode") private var appearanceMode = "system"

    @Query private var allEntries: [Entry]

    @State private var onboardingStep: OnboardingStep?
    @State private var isOnboardingCapture = false
    @State private var prefill: CapturePrefill?
    @State private var route: Route?

    enum Route: String, Identifiable {
        case history
        case recap
        case frontDoors
        case settings

        var id: String { rawValue }
    }

    private var hasAnyEntry: Bool { !allEntries.isEmpty }

    var body: some View {
        NavigationStack {
            LogHomeView(
                isOnboarding: isOnboardingCapture,
                prefill: prefill,
                onLogged: {
                    onboardingStepRaw = OnboardingStep.categories.rawValue
                    isOnboardingCapture = false
                    onboardingStep = .categories
                },
                onCancelOnboarding: {
                    isOnboardingCapture = false
                    onboardingActive = false
                }
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            route = .history
                        } label: {
                            Label("History", systemImage: "clock")
                        }
                        Button {
                            route = .recap
                        } label: {
                            Label("Recap", systemImage: "chart.bar")
                        }
                        Divider()
                        Button {
                            route = .frontDoors
                        } label: {
                            Label("Log without opening TapLog", systemImage: "sparkles")
                        }
                        Divider()
                        Button {
                            route = .settings
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .applyAppearanceOverride()
        .tint(Theme.accent)
        .onAppear {
            handleLaunchFlow()
            // Dev/testing hooks:
            //   `-route history` opens a sheet; `-appearance dark` flips the appearance
            //   in-app shortly after launch (exercises the live-update path while a
            //   sheet may be up, exactly like the user changing it in Settings).
            let args = ProcessInfo.processInfo.arguments
            if let index = args.lastIndex(of: "-route"),
               args.indices.contains(index + 1),
               let route = Route(rawValue: args[index + 1]) {
                self.route = route
            }
            if let index = args.lastIndex(of: "-appearance"),
               args.indices.contains(index + 1) {
                let value = args[index + 1]
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    appearanceMode = value
                }
            }
        }
        .onOpenURL { url in
            guard let prefill = CapturePrefill(url: url) else { return }
            self.prefill = prefill
        }
        .sheet(item: $route) { route in
            Group {
                switch route {
                case .history:
                    EntryListView()
                        .environmentObject(undoStack)
                case .recap:
                    WeeklyRecapView()
                case .frontDoors:
                    SetupFrontDoorsView()
                case .settings:
                    SettingsView()
                }
            }
            .applyAppearanceOverride()
        }
        .fullScreenCover(item: $onboardingStep, onDismiss: {
            onboardingStep = nil
        }) { step in
            onboardingView(for: step)
                .applyAppearanceOverride()
        }
        .overlay(alignment: .bottom) { UndoToast() }
    }

    // MARK: - Onboarding

    private func handleLaunchFlow() {
        // Slight delay so a cold-start deep link (widget/Siri) can arrive first and
        // suppress the welcome — don't ambush someone who came to log something.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if !hasLaunchedBefore && prefill == nil {
                hasLaunchedBefore = true
                onboardingActive = true
                onboardingStepRaw = OnboardingStep.capture.rawValue
                onboardingStep = .welcome
            } else if onboardingActive && onboardingStep == nil && prefill == nil {
                // Killed mid-onboarding: resume at the stored step, never at the welcome.
                switch OnboardingStep(rawValue: onboardingStepRaw) {
                case .capture:
                    isOnboardingCapture = true
                case .categories, .frontDoors:
                    onboardingStep = OnboardingStep(rawValue: onboardingStepRaw)
                default:
                    break
                }
            }
        }
    }

    @ViewBuilder
    private func onboardingView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeView(
                onContinue: {
                    // Already logged via another door? Skip the "first log" beat.
                    onboardingStep = nil
                    if hasAnyEntry {
                        onboardingStepRaw = OnboardingStep.categories.rawValue
                        onboardingStep = .categories
                    } else {
                        onboardingStepRaw = OnboardingStep.capture.rawValue
                        isOnboardingCapture = true
                    }
                },
                onSkip: {
                    onboardingStep = nil
                    onboardingActive = false
                }
            )
        case .capture:
            // Never a cover — the home tab IS the capture form (isOnboardingCapture).
            EmptyView()
        case .categories:
            OnboardingCategoriesView(onContinue: {
                onboardingStepRaw = OnboardingStep.frontDoors.rawValue
                onboardingStep = .frontDoors
            })
        case .frontDoors:
            SetupFrontDoorsView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(StoreLocator.makeContainer())
        .environmentObject(UndoStack())
}
