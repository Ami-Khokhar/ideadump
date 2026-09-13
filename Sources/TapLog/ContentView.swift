import SwiftUI
import SwiftData
import Combine

/// App root: a single capture-first home screen. History, Budgets and Recap sit on
/// the navigation bar beside it; Settings (and the front doors it holds) stay behind
/// the dropdown so the home page stays a logging surface first. Also hosts the
/// first-session onboarding state machine,
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

    @Query private var allCategories: [SpendCategory]

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
    /// Set when a log lands, cleared when the undo toast for it goes away.
    ///
    /// A prompt presented while the toast is alive would cover it and take the
    /// undo with it — the toast is an overlay on this root, so any sheet sits on
    /// top. Waiting for the toast to clear also means waiting on the toast's own
    /// signal rather than a second guessed delay.
    @State private var awaitingPromptCheck = false
    /// Destination to open once a first-run explainer is dismissed. Set only by
    /// `openRoute`, so the explainer and the screen it describes are presented
    /// one after the other rather than stacked as two sheets.
    @State private var routeAfterExplainer: Route?

    enum Route: String, Identifiable {
        case history
        case categories
        case budgets
        case recap
        case budgetsExplainer
        case recapExplainer
        case frontDoors
        case settings

        var id: String { rawValue }
    }

    enum DeferredPrompt: String, Identifiable {
        case categories
        case firstBudget
        case fasterWays

        var id: String { rawValue }
    }

    private var hasConfirmedEntry: Bool { !confirmedEntries.isEmpty }

    /// Whether this launch suppresses the opening animation.
    ///
    /// One case only: a widget or Siri activation. That user has already said
    /// what they came to do, and this app's entire pitch is that logging takes
    /// about five seconds — an animation is not worth a third of that when the
    /// amount is already on its way in. Every ordinary launch plays it.
    private var skipSplash: Bool {
        intentDirectCapture
    }

    /// A category counts as budgeted only with both halves set — a target with no
    /// cadence is an unfinished budget, and the grove does not grow a tree for it.
    private var hasAnyBudget: Bool {
        allCategories.contains { ($0.budgetTarget ?? 0) > 0 && $0.budgetPeriod != nil }
    }

    var body: some View {
        NavigationStack {
            LogHomeView(
                isOnboarding: isOnboardingCapture,
                prefill: prefill,
                onLogged: {
                    // A log is what earns the next setup prompt, but the undo
                    // toast owns the screen for the five seconds after it. Arm
                    // the check and let the toast finish; see `awaitingPromptCheck`.
                    awaitingPromptCheck = true
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
                skipSplash: skipSplash
            )
            // The three screens the app exists to pay off with sit on the bar,
            // one tap from the capture surface. They used to live inside the ⋯
            // menu, which is where features go to be forgotten — nobody opens a
            // menu to discover whether an app has anything to show them, so a
            // recap nobody found was a recap nobody had.
            //
            // Budgets earns a button of its own rather than relying on the grove
            // strip alone: the strip only exists once a budget does, so on a
            // fresh install it is exactly the person with no trees who would have
            // had no way to plant one.
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        route = .history
                    } label: {
                        Label("History", systemImage: "clock")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        openRoute(.budgets)
                    } label: {
                        Label("Budgets", systemImage: "leaf")
                    }
                    Button {
                        openRoute(.recap)
                    } label: {
                        Label("Recap", systemImage: "chart.bar")
                    }
                    Menu {
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
            // Consume any pending intent activation written before the UI was ready.
            consumePendingIntent()
            // A widget tap can cold-launch the app, and this view can appear before
            // the didBecomeActive subscriber below is listening. The receipt is
            // consumed once, so running it in both places offers the undo exactly once.
            offerWidgetUndo()
            // Reconcile durable SwiftData truth before deciding whether to show
            // welcome or deferred prompts after a cold relaunch.
            reconcileOnboarding(with: confirmedEntries.count)
            // Start the delayed onboarding flow (unless an activation was handled).
            handleLaunchFlow()
#if DEBUG
            // Dev/testing hooks. Debug-only: these rewrite onboarding state,
            // navigation, and appearance from a launch argument, and none of
            // them should be reachable in anything a user installs.
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
#endif
        }
        // Handle warm/background activation: the scene becomes active after the
        // intent wrote its payload while the app was suspended.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            consumePendingIntent()
            offerWidgetUndo()
            reconcileOnboarding(with: confirmedEntries.count)
            handleLaunchFlow()
        }
        // Handle in-process activation: OpenCaptureIntent writes the durable
        // payload to UserDefaults then posts this notification so ContentView
        // can consume it immediately, even when the scene is already active
        // (didBecomeActiveNotification won't fire in that case).
        // The weekly recap notification is the app's only one, and this is the
        // only thing tapping it does: open the screen it was about.
        .onReceive(NotificationCenter.default.publisher(for: RecapNotifier.openRecapNotification)) { _ in
            route = .recap
        }
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
        // A receipt held back by the guard in `offerWidgetUndo` gets its chance
        // here: closing the sheet is the screen becoming clear, and no
        // activation notification fires for that.
        .onChange(of: route) { _, newValue in
            if newValue == nil { offerWidgetUndo() }
        }
        // The toast going away is the screen becoming free — whether it timed
        // out or the user took the log back with Undo.
        .onChange(of: undoStack.current == nil) { _, isClear in
            guard isClear, awaitingPromptCheck else { return }
            awaitingPromptCheck = false
            presentDeferredPromptIfDue()
        }
        .sheet(item: $route, onDismiss: continueAfterExplainer) { route in
            Group {
                switch route {
                case .history:
                    EntryListView()
                        .environmentObject(undoStack)
                case .categories:
                    CategoryManageView()
                case .budgets:
                    BudgetsView()
                case .recap:
                    WeeklyRecapView()
                case .budgetsExplainer:
                    FeatureExplainerView.budgets
                case .recapExplainer:
                    FeatureExplainerView.recap
                case .frontDoors:
                    SetupFrontDoorsView(onDone: {
                        OnboardingFlow.dismissFasterWays()
                    })
                case .settings:
                    SettingsView()
                }
            }
            .applyAppearanceOverride()
            // The root `.tint` above is applied *inside* this `.sheet` modifier, so
            // presented routes start from the environment's default blue rather than
            // sage — which is why the capture screen's category picker looked themed
            // while the same List opened from the menu did not. Re-apply it here.
            .tint(Theme.accent)
        }
        .fullScreenCover(item: $onboardingStep, onDismiss: {
            onboardingStep = nil
        }) { step in
            onboardingView(for: step)
                .applyAppearanceOverride()
                // Same reason as the route sheet above: presented content sits
                // outside the root `.tint`, so it starts from the system default.
                .tint(Theme.accent)
        }
        .sheet(item: $deferredPrompt, onDismiss: {
            if let activeDeferredPrompt {
                switch activeDeferredPrompt {
                case .categories:
                    OnboardingFlow.dismissCategories()
                case .firstBudget:
                    OnboardingFlow.dismissFirstBudget()
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
                .tint(Theme.accent)
                .onAppear { activeDeferredPrompt = .categories }
            case .firstBudget:
                FirstBudgetView(onDone: {
                    OnboardingFlow.dismissFirstBudget()
                    deferredPrompt = nil
                })
                .presentationDetents([.large])
                .tint(Theme.accent)
                .onAppear { activeDeferredPrompt = .firstBudget }
            case .fasterWays:
                SetupFrontDoorsView(onDone: {
                    OnboardingFlow.dismissFasterWays()
                    deferredPrompt = nil
                })
                .presentationDetents([.medium, .large])
                .tint(Theme.accent)
                .onAppear { activeDeferredPrompt = .fasterWays }
            }
        }
        .overlay(alignment: .bottom) { UndoToast() }
    }

    // MARK: - Intent Routing

    /// Consumes a persisted pending activation. Only changes routing state when
    /// the result is `.open`; an ordinary launch (`.none`) is a no-op.
    /// Opens `destination`, showing its one-time explainer first when the user
    /// has not seen it. The explainer is presented as the only sheet; dismissing
    /// it continues on to `destination` from `continueAfterExplainer`.
    private func openRoute(_ destination: Route) {
        switch destination {
        case .budgets where OnboardingFlow.shouldShowExplainer(OnboardingFlow.budgetsExplainerSeenKey):
            OnboardingFlow.markExplainerSeen(OnboardingFlow.budgetsExplainerSeenKey)
            routeAfterExplainer = destination
            route = .budgetsExplainer
        case .recap where OnboardingFlow.shouldShowExplainer(OnboardingFlow.recapExplainerSeenKey):
            OnboardingFlow.markExplainerSeen(OnboardingFlow.recapExplainerSeenKey)
            routeAfterExplainer = destination
            route = .recapExplainer
        default:
            route = destination
        }
    }

    /// Continues to the screen an explainer was standing in front of. Presenting
    /// straight from `onDismiss` races the dismissal animation, so the next sheet
    /// is scheduled once the current one has actually gone away.
    private func continueAfterExplainer() {
        guard let next = routeAfterExplainer else { return }
        routeAfterExplainer = nil
        DispatchQueue.main.async { route = next }
    }

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

    /// Shows the five-second undo toast for an expense the widget logged while the
    /// app was closed. The widget cannot show a toast of its own — it has no screen
    /// after the tap — so the app owes the user one the next time it opens.
    ///
    /// Silent when nothing is pending, when the log is older than the receipt's
    /// window, or when the entry has already been removed some other way.
    private func offerWidgetUndo() {
        // The toast is an overlay on the root, so a sheet or a cover sits on top
        // of it. Consuming the receipt behind one would spend the widget's only
        // undo on a toast nobody can see — and `consume` clears the slot, so it
        // could never be offered again. Leave it where it is instead: whichever
        // comes first, a clear screen or the end of the receipt's window.
        guard route == nil, onboardingStep == nil, deferredPrompt == nil else { return }
        guard let receipt = WidgetLogReceipt.consume() else { return }
        let stamp = receipt.createdAt
        let descriptor = FetchDescriptor<Entry>(predicate: #Predicate<Entry> { $0.createdAt == stamp })
        guard let entry = try? modelContext.fetch(descriptor).first else { return }

        let name = CategoryLookup(allCategories).name(for: entry.category)

        // A widget tap is a log too, and this toast gives the same clean
        // hand-off the keypad's does. Without this, someone who only ever logs
        // from the widget would never be offered the setup prompts at all.
        awaitingPromptCheck = true

        // Leads with the source and stays short: the toast is one line wide, and
        // "Logged ₹80.00 · Chai from the widget" truncated to "from the…".
        undoStack.record("Widget logged \(Money.format(entry.amount)) · \(name)") {
            let undone = CaptureBookkeeping.undoLog(
                entry: entry,
                modelContext: modelContext,
                categories: allCategories
            )
            // `undo()` clears the toast before running this, so a refused undo
            // would otherwise look exactly like one that worked.
            if !undone {
                undoStack.report("Could not undo that. The expense is still in History.")
            }
        }
    }

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

        }
    }

    /// Offers the next setup prompt, if one is due.
    ///
    /// This used to run on the 0.4-second launch timer above, which put the
    /// sheet on screen 0.4s into a 2.1-second opening animation — the plant was
    /// still sprouting behind it and the wordmark had not appeared yet. The two
    /// clocks never knew about each other.
    ///
    /// It now follows a log instead, which is both a settled screen and the
    /// moment each of these is actually about: the user has just categorised
    /// something, just spent against a budget they do not have yet, or just
    /// typed an amount they could have logged from the widget.
    ///
    /// The conditions are re-checked here rather than when the log happened, so
    /// a log the user took back with Undo cannot leave a prompt behind.
    private func presentDeferredPromptIfDue() {
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
        } else if OnboardingFlow.shouldOfferFirstBudget(
            confirmedLogCount: confirmedEntries.count,
            hasAnyBudget: hasAnyBudget
        ) {
            deferredPrompt = .firstBudget
        } else if OnboardingFlow.shouldOfferFasterWays(
            confirmedLogCount: confirmedEntries.count,
            isFirstLogSession: loggedInCurrentSession
        ) {
            deferredPrompt = .fasterWays
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
