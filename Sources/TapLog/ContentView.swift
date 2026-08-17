import SwiftUI
import SwiftData

/// App root: three tabs — Log (capture-first home, the default), History, Recap.
/// Also hosts the first-session onboarding state machine, deep-link prefill, and the
/// app-wide undo toast so it works from any tab.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var undoStack: UndoStack

    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @AppStorage("onboardingActive") private var onboardingActive = false
    @AppStorage("onboardingStepRaw") private var onboardingStepRaw = OnboardingStep.capture.rawValue

    @Query private var allEntries: [Entry]

    @State private var selectedTab = 0
    @State private var onboardingStep: OnboardingStep?
    @State private var isOnboardingCapture = false
    @State private var prefill: CapturePrefill?

    private var hasAnyEntry: Bool { !allEntries.isEmpty }

    var body: some View {
        TabView(selection: $selectedTab) {
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
                },
                selectedTab: $selectedTab
            )
            .tabItem { Label("Log", systemImage: "plus.circle") }
            .tag(0)

            EntryListView()
                .tabItem { Label("History", systemImage: "clock") }
                .tag(1)

            WeeklyRecapView()
                .tabItem { Label("Recap", systemImage: "chart.bar") }
                .tag(2)
        }
        .tint(Theme.accent)
        .onAppear {
            handleLaunchFlow()
            // Dev/testing hook: `simctl launch ... -tab 1` opens a specific tab.
            let args = ProcessInfo.processInfo.arguments
            if let index = args.lastIndex(of: "-tab"),
               args.indices.contains(index + 1),
               let raw = Int(args[index + 1]),
               (0...2).contains(raw) {
                selectedTab = raw
            }
        }
        .onOpenURL { url in
            guard let prefill = CapturePrefill(url: url) else { return }
            self.prefill = prefill
            selectedTab = 0
        }
        .fullScreenCover(item: $onboardingStep, onDismiss: {
            onboardingStep = nil
        }) { step in
            onboardingView(for: step)
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
