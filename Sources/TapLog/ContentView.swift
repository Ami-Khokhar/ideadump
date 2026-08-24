import SwiftUI
import SwiftData
import Combine

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

    @Query(filter: #Predicate<Entry> { !$0.isArchived && !$0.isPending })
    private var confirmedEntries: [Entry]

    @State private var onboardingStep: OnboardingStep?
    @State private var isOnboardingCapture = false
    @State private var prefill: CapturePrefill?
    @State private var route: Route?
    /// When true the logo splash is skipped and the capture screen is revealed
    /// immediately. Set by a pending intent activation.
    @State private var intentDirectCapture = false
    /// Tracks that the current launch handled a direct-capture activation, so the
    /// delayed onboarding flow cannot override it.
    @State private var handledActivation = false
    @State private var deferredPrompt: DeferredPrompt?
    @State private var activeDeferredPrompt: DeferredPrompt?
    @State private var loggedInCurrentSession = false
    @State private var suppressDeferredPromptsThisSession = false

    enum Route: String, Identifiable {
        case history
        case recap
        case frontDoors
        case settings

        var id: String { rawValue }
    }

    enum DeferredPrompt: String, Identifiable {
        case categories
        case fasterWays

        var id: String { rawValue }
    }

    private var hasConfirmedEntry: Bool { !confirmedEntries.isEmpty }

    var body: some View {
        NavigationStack {
            LogHomeView(
                isOnboarding: isOnboardingCapture,
                prefill: prefill,
                onLogged: {
                    // The first log completes core onboarding, but never interrupts
                    // the capture surface with a second setup screen.
                    guard isOnboardingCapture else { return }
                    completeCoreOnboarding()
                    OnboardingFlow.markCoreComplete()
                },
                onCancelOnboarding: {
                    isOnboardingCapture = false
                    onboardingActive = false
                },
                onPrefillConsumed: {
                    prefill = nil
                },
                skipSplash: intentDirectCapture
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
                            Label("Faster ways to log", systemImage: "sparkles")
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
            // Legacy onboarding state must be migrated before any confirmed-entry
            // reconciliation can change the live/core flags.
            OnboardingFlow.migrate()
            // Consume any pending intent activation written before the UI was ready.
            consumePendingIntent()
            // Reconcile durable SwiftData truth before deciding whether to show
            // welcome or deferred prompts after a cold relaunch.
            reconcileOnboarding(with: confirmedEntries.count)
            // Start the delayed onboarding flow (unless an activation was handled).
            handleLaunchFlow()
            // Dev/testing hooks
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-onboarding") {
                hasLaunchedBefore = true
                onboardingActive = true
                onboardingStepRaw = OnboardingStep.capture.rawValue
                isOnboardingCapture = true
                handledActivation = false
            }
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
        // Handle warm/background activation: the scene becomes active after the
        // intent wrote its payload while the app was suspended.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            OnboardingFlow.migrate()
            consumePendingIntent()
            reconcileOnboarding(with: confirmedEntries.count)
            handleLaunchFlow()
        }
        // Handle in-process activation: OpenCaptureIntent writes the durable
        // payload to UserDefaults then posts this notification so ContentView
        // can consume it immediately, even when the scene is already active
        // (didBecomeActiveNotification won't fire in that case).
        .onReceive(NotificationCenter.default.publisher(for: OpenCaptureIntent.activationNotification)) { _ in
            consumePendingIntent()
        }
        .onReceive(NotificationCenter.default.publisher(for: OnboardingFlow.coreCompletionNotification)) { _ in
            completeCoreOnboarding(markSessionLog: false)
            suppressDeferredPromptsThisSession = true
        }
        .onChange(of: confirmedEntries.count) { _, count in
            reconcileOnboarding(with: count)
        }
        .onOpenURL { url in
            guard let prefill = CapturePrefill(url: url) else { return }
            routeToDirectCapture(prefill: prefill, recordDirectUse: true)
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
                    SetupFrontDoorsView(onDone: {
                        OnboardingFlow.dismissFasterWays()
                    })
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
        .sheet(item: $deferredPrompt, onDismiss: {
            if let activeDeferredPrompt {
                switch activeDeferredPrompt {
                case .categories:
                    OnboardingFlow.dismissCategories()
                case .fasterWays:
                    OnboardingFlow.dismissFasterWays()
                }
            }
            activeDeferredPrompt = nil
        }) { prompt in
            switch prompt {
            case .categories:
                OnboardingCategoriesView(onContinue: {
                    OnboardingFlow.dismissCategories()
                    deferredPrompt = nil
                })
                .presentationDetents([.large])
                .onAppear { activeDeferredPrompt = .categories }
            case .fasterWays:
                SetupFrontDoorsView(onDone: {
                    OnboardingFlow.dismissFasterWays()
                    deferredPrompt = nil
                })
                .presentationDetents([.medium, .large])
                .onAppear { activeDeferredPrompt = .fasterWays }
            }
        }
        .overlay(alignment: .bottom) { UndoToast() }
    }

    // MARK: - Intent Routing

    /// Consumes a persisted pending activation. Only changes routing state when
    /// the result is `.open`; an ordinary launch (`.none`) is a no-op.
    private func consumePendingIntent() {
        let activation = OpenCaptureIntent.consumePendingActivation()
        guard case .open(let pendingPrefill) = activation else { return }

        preserveAwaitingFirstConfirmedLogIfNeeded()

        // Mark that we handled an activation — the delayed onboarding must not
        // override this.
        handledActivation = true
        intentDirectCapture = true

        if let pendingPrefill {
            routeToDirectCapture(prefill: pendingPrefill)
        }

        // Dismiss any open sheet or onboarding cover.
        route = nil
        deferredPrompt = nil
        onboardingStep = nil
        onboardingActive = false
        isOnboardingCapture = false
    }

    // MARK: - Onboarding

    private func handleLaunchFlow() {
        // Slight delay so a cold-start deep link (widget/Siri) can arrive first and
        // suppress the welcome — don't ambush someone who came to log something.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // If a direct-capture activation was handled, never present onboarding.
            guard !handledActivation else { return }

            // The initial query can be populated after onAppear; repeat the
            // reconciliation at the start of the delayed launch decision.
            reconcileOnboarding(with: confirmedEntries.count)

            if !hasLaunchedBefore && prefill == nil && !hasConfirmedEntry {
                hasLaunchedBefore = true
                onboardingActive = true
                onboardingStepRaw = OnboardingStep.capture.rawValue
                onboardingStep = .welcome
                return
            } else if !hasLaunchedBefore {
                // A headless/widget/deep-link log is already a meaningful first
                // action. Do not make the next app launch replay setup screens.
                hasLaunchedBefore = true
                OnboardingFlow.markCoreComplete()
                suppressDeferredPromptsThisSession = true
                return
            } else if onboardingActive && onboardingStep == nil && prefill == nil {
                // Killed mid-onboarding: resume at the stored step, never at the welcome.
                switch OnboardingStep(rawValue: onboardingStepRaw) {
                case .capture:
                    isOnboardingCapture = true
                case .categories, .frontDoors:
                    // Old builds persisted these as mandatory covers. Migration
                    // converts them into optional prompts instead.
                    onboardingActive = false
                default:
                    break
                }
            }

            guard OnboardingFlow.canScheduleDeferredPrompts(
                onboardingActive: onboardingActive,
                hasOnboardingCover: onboardingStep != nil,
                routeActive: route != nil,
                deferredPromptActive: deferredPrompt != nil,
                activeDeferredPrompt: activeDeferredPrompt != nil,
                prefillActive: prefill != nil,
                loggedInCurrentSession: loggedInCurrentSession,
                suppressForCurrentSession: suppressDeferredPromptsThisSession
            ) else { return }
            if OnboardingFlow.shouldOfferCategories(confirmedLogCount: confirmedEntries.count) {
                deferredPrompt = .categories
            } else if OnboardingFlow.shouldOfferFasterWays(
                confirmedLogCount: confirmedEntries.count,
                isFirstLogSession: loggedInCurrentSession
            ) {
                deferredPrompt = .fasterWays
            }
        }
    }

    @ViewBuilder
    private func onboardingView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeView(
                onContinue: {
                    // Already logged via another door? Finish core onboarding and
                    // leave the user on the home screen.
                    onboardingStep = nil
                    if hasConfirmedEntry {
                        onboardingActive = false
                        OnboardingFlow.markCoreComplete()
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
            EmptyView()
        case .frontDoors:
            EmptyView()
        }
    }

    private func routeToDirectCapture(prefill: CapturePrefill?, recordDirectUse: Bool = false) {
        preserveAwaitingFirstConfirmedLogIfNeeded()
        handledActivation = true
        intentDirectCapture = true
        self.prefill = prefill
        if recordDirectUse {
            OnboardingFlow.recordIntentUse(OnboardingFlow.directCaptureUsedKey)
        }
        route = nil
        deferredPrompt = nil
        onboardingStep = nil
        onboardingActive = false
        isOnboardingCapture = false
    }

    private func preserveAwaitingFirstConfirmedLogIfNeeded() {
        let coreComplete = UserDefaults.standard.bool(forKey: OnboardingFlow.coreCompleteKey)
        let shouldAwait = OnboardingFlow.shouldAwaitFirstConfirmedLog(
            coreComplete: coreComplete,
            confirmedLogCount: confirmedEntries.count
        )
        if shouldAwait {
            OnboardingFlow.markAwaitingFirstConfirmedLog()
        }
    }

    private func completeCoreOnboarding(markSessionLog: Bool = true) {
        guard isOnboardingCapture || onboardingStep != nil || onboardingActive else { return }
        isOnboardingCapture = false
        onboardingActive = false
        onboardingStep = nil
        if markSessionLog {
            loggedInCurrentSession = true
        }
    }

    private func reconcileOnboarding(with confirmedCount: Int) {
        let liveOnboardingActive = onboardingActive || isOnboardingCapture || onboardingStep != nil
        guard OnboardingFlow.reconcileCoreIfNeeded(
            confirmedLogCount: confirmedCount,
            onboardingActive: liveOnboardingActive
        ) else { return }

        // Cross-process intents/share confirmations may update SwiftData without
        // emitting this process's completion notification. Clear live state here
        // as well, and suppress deferred prompts for this session.
        completeCoreOnboarding(markSessionLog: false)
        suppressDeferredPromptsThisSession = true
    }
}

#Preview {
    ContentView()
        .modelContainer(StoreLocator.makeContainer())
        .environment(RetentionManager())
        .environmentObject(UndoStack())
}
