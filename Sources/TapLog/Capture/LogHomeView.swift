import SwiftUI
import SwiftData

/// The capture-first home screen. Minimal — 6 elements, zero clutter.
///
/// Flow: tap tile → type amount → tap Log. Two taps for a daily repeat.
/// One-off: type amount → tap "+ More" → pick category.
struct LogHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(RetentionManager.self) private var retention
    @EnvironmentObject private var undoStack: UndoStack

    @AppStorage("lastUsedCategory") private var lastUsedCategoryKey: String = SpendCategory.fallbackKey

    @Query(sort: \SpendCategory.sortOrder) private var categories: [SpendCategory]
    @Query(
        filter: #Predicate<Entry> { !$0.isArchived && !$0.isPending },
        sort: \Entry.date,
        order: .reverse
    ) private var activeEntries: [Entry]

    @State private var amountText = ""
    @State private var selectedCategoryKey = ""
    /// Never typed on this screen any more — the note field was removed from
    /// capture. It survives because a share-sheet import or deep link can carry
    /// a note in through `applyPrefill`, and because the History edit sheet can
    /// add one afterwards.
    @State private var note = ""
    /// nil until the user answers — see `intentButton`. Unmarked is a real
    /// third state, not a missing value: Recap reports shares over marked spend
    /// only, so an unanswered entry makes no claim either way.
    @State private var intent: SpendIntent?
    @State private var showingCategoryPicker = false
    @State private var showingManageCategories = false
    @State private var amountError: String?
    /// Opening animation: 0 = logo visible, 1 = content visible
    @State private var openingPhase: CGFloat = 0

    let isOnboarding: Bool
    let prefill: CapturePrefill?
    let onLogged: (() -> Void)?
    let onCancelOnboarding: (() -> Void)?
    let onPrefillConsumed: (() -> Void)?
    /// When true the logo splash is skipped — used by OpenCaptureIntent.
    let skipSplash: Bool

    private var lookup: CategoryLookup { CategoryLookup(categories) }

    private var topCategories: [SpendCategory] {
        let keys = CategorySuggestions.topCategories(
            entries: activeEntries,
            categories: categories,
            maxSlots: 4
        )
        return keys.compactMap { key in
            categories.first { $0.key == key }
        }
    }

    private var canLog: Bool {
        AmountInputFilter.isValid(amountText)
    }

    var body: some View {
        ZStack {
            // Background
            PaperGround().ignoresSafeArea()

            // No grove here. A horizon was tried behind the amount and removed:
            // it gave the eye a second place to land on a screen whose job is
            // one number. The trees have a screen of their own on Budgets,
            // which is where they are big enough to read.
            //
            // The vines are the exception, and only because they stay in the
            // margins: they frame the number instead of sitting beside it.
            VineBorder()
                .opacity(openingPhase)
                .ignoresSafeArea()

            // The opening plant (fades out as content fades in)
            openingView
                .opacity(1 - openingPhase)
                .ignoresSafeArea()

            // Main content (fades in)
            mainContent
                .opacity(openingPhase)
        }
        .onAppear {
            applyPrefill()
            if skipSplash || reduceMotion || isOnboarding {
                // Straight to capture, no opening. Reduce Motion is included
                // because the plant is decoration: someone who asked for no
                // motion gains nothing from a still of it standing in the way
                // of the keypad for a second and a half. The guided first-log
                // step skips it too — that is a step inside onboarding, not
                // someone opening the app.
                openingPhase = 1
            }
            // Otherwise the opening runs, on this and every ordinary launch.
            // Nothing to schedule here: the dissolve is triggered by the
            // animation itself, through `revealCapture`, because only it knows
            // when it started drawing. Measured from this point the plant grew
            // behind the launch image and was over before anyone saw it.
#if DEBUG
            // Test hook: `simctl launch ... -autolog 42` logs an expense without a
            // human at the keypad. Debug-only — a shipped build that logs money
            // because of a launch argument is a bug with a spending consequence.
            let args = ProcessInfo.processInfo.arguments
            if let index = args.lastIndex(of: "-autolog"), args.indices.contains(index + 1) {
                let value = args[index + 1]
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    amountText = value
                    save()
                }
            }
#endif
        }
        .onChange(of: skipSplash) { _, newValue in
            // Handle intent activation received after onAppear — e.g. the app
            // was already visible when OpenCaptureIntent fired.
            if newValue && openingPhase < 1 {
                withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 1.0)) {
                    openingPhase = 1
                }
            }
        }
        .onChange(of: prefill) { applyPrefill() }
        .onChange(of: categories.count) { resolveLastUsedCategoryIfNeeded() }
        .sheet(isPresented: $showingManageCategories) {
            CategoryManageView()
        }
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryPickerView(
                onSelect: { categoryKey in
                    selectedCategoryKey = categoryKey
                    showingCategoryPicker = false
                },
                onManage: {
                    showingCategoryPicker = false
                    DispatchQueue.main.async {
                        showingManageCategories = true
                    }
                }
            )
        }
    }

    // MARK: - Opening

    private var openingView: some View {
        SeedGrowthView(onFinished: revealCapture)
    }

    /// Dissolves the opening through to the capture screen. Called when the
    /// wordmark settles, so the plant does not add a second toll on top of its
    /// own.
    private func revealCapture() {
        guard openingPhase < 1 else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 1.0)) {
            openingPhase = 1
        }
    }

    // MARK: - Main Content

    /// The keypad and Log button are pinned as a bottom inset so the two controls
    /// that finish the task are always under the thumb, whatever the screen height.
    /// Everything above them scrolls, which is what keeps this usable on a 4.7"
    /// device where the keypad alone claims most of the viewport.
    private var mainContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Deliberately empty above the amount. This screen used to open
                // with a streak wreath, today's total and a "Use the keypad"
                // hint stacked over the number they were competing with. All
                // three are gone: the streak has its own screen, today's total
                // is on History, and the hint taught a keypad that is already
                // the only thing on the lower half of the screen.
                //
                // No trees either, in any form — a grove strip, tile badges and
                // a background horizon were each tried and each gave the eye a
                // second place to land. What survives is the one 2pt rule under
                // each tile, which adds no object to the row.
                Spacer(minLength: 48)
                amountArea
                Spacer(minLength: 36)
                categoryLine
                tileRow()
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                // Unconditional now. The keypad used to yield the bottom of the
                // screen whenever the note field raised the system keyboard;
                // with the note field gone from capture, nothing on this screen
                // summons a keyboard, so the keypad is always the thing here.
                keypad
                logButton
                    .padding(.bottom, CaptureBottomBar.logButtonBottomPadding)
                    .padding(.top, CaptureBottomBar.logButtonLiftPadding)
            }
            .background(Theme.paper)
        }
    }

    // MARK: - 2. Amount Area

    /// The amount is a *display*, not a text field: entry happens on the in-app
    /// keypad below. The system decimal pad used to animate in over the lower
    /// third of this screen, so the layout had to reserve that space and sat
    /// half-empty until the keyboard arrived — a visible pause on a task the app
    /// advertises as taking five seconds. Owning the keypad removes the pause and
    /// puts the amount, the tiles and Log inside one thumb arc.
    private var amountArea: some View {
        VStack(spacing: 8) {
            // The "Use the keypad, then Log." hint used to sit here. It taught a
            // keypad that already fills the lower half of the screen, and it sat
            // directly above the one number this screen exists for.

            let fontSize = AmountFont.focalFontSize(for: amountText, dynamicTypeSize: dynamicTypeSize)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Money.currencySymbol)
                    .font(Theme.focal(fontSize * 0.38, weight: .regular))
                    .foregroundStyle(Theme.textTertiary)
                    .accessibilityHidden(true)
                Text(amountText.isEmpty ? "0" : amountText)
                    // Serif digits are proportional by default, so the amount
                    // would shift sideways as each key lands. Monospacing the
                    // digits keeps it still while it grows.
                    .font(Theme.focal(fontSize, weight: .regular).monospacedDigit())
                    .foregroundStyle(amountText.isEmpty ? Theme.textTertiary : Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .contentTransition(.numericText())
            }
            .frame(height: AmountLayout.focalHeroHeight(fontSize: fontSize))
            .animation(reduceMotion ? nil : Motion.gentleFast, value: amountText)

            if let error = amountError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Theme.clay)
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            amountText.isEmpty
                ? "Amount, empty"
                : "Amount \(Money.format(AmountInputFilter.parsedAmount(amountText) ?? 0))"
        )
    }

    // MARK: - 2b. Keypad

    /// Digits laid out as a phone keypad. The decimal separator follows the
    /// user's locale so the glyph on the key matches what `Money.parse` expects.
    private var keypadKeys: [String] {
        let separator = Locale.current.decimalSeparator ?? "."
        return ["1", "2", "3", "4", "5", "6", "7", "8", "9", separator, "0", ""]
    }

    private var keypad: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: CaptureBottomBar.keySpacing), count: 3),
            spacing: CaptureBottomBar.keySpacing
        ) {
            ForEach(Array(keypadKeys.enumerated()), id: \.offset) { _, key in
                if key.isEmpty {
                    keypadButton(label: nil, action: deleteAmountCharacter)
                        .accessibilityLabel("Delete")
                } else {
                    keypadButton(label: key) { appendAmountCharacter(key) }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func keypadButton(label: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let label {
                    Text(label)
                        .font(Theme.amount(26, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                } else {
                    Image(systemName: "delete.left")
                        .font(.title3)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: CaptureBottomBar.keyHeight)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressStyle())
    }

    // MARK: - Keypad input

    /// Routes a key press through the same `AmountInputFilter.filterEdit` path the
    /// UIKit field uses, so separator rules, the two-decimal cap and the maximum
    /// amount stay in one tested place rather than being re-implemented here.
    private func appendAmountCharacter(_ character: String) {
        let result = AmountInputFilter.filterEdit(
            current: amountText,
            range: NSRange(location: (amountText as NSString).length, length: 0),
            replacement: character
        )
        setAmountError(result.error)
        guard !result.restoresPrevious else {
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }
        amountText = result.text
    }

    private func deleteAmountCharacter() {
        guard !amountText.isEmpty else { return }
        let length = (amountText as NSString).length
        let result = AmountInputFilter.filterEdit(
            current: amountText,
            range: NSRange(location: length - 1, length: 1),
            replacement: ""
        )
        setAmountError(result.error)
        amountText = result.text
    }

    // MARK: - 3. Category Line

    private var categoryLine: some View {
        HStack(spacing: 8) {
            if selectedCategoryKey.isEmpty {
                Text("No category")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textTertiary)
            } else {
                Text("\(lookup.emoji(for: selectedCategoryKey)) \(lookup.name(for: selectedCategoryKey))")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
            }

            Text("·")
                .foregroundStyle(Theme.textTertiary)

            intentButton
        }
        .padding(.vertical, 4)
    }

    /// Three-state intent control: unmarked → impulse → planned → unmarked.
    ///
    /// Cycling rather than a segmented control, for two reasons. The line is the
    /// most contested one-line strip on the screen and a third option would
    /// either widen it or shrink the category name; and — more importantly — the
    /// happy path must stay untouched. Unmarked is the resting state, so logging
    /// is still amount → Log with no detour, and the control costs a tap only
    /// when the user chooses to answer.
    ///
    /// The order answers the question the resting label asks. "Impulse?" is an
    /// invitation, so the first tap says yes; the second corrects it to Planned;
    /// the third takes the answer back. Unmarked stays tertiary and glyph-less so
    /// it reads as a prompt rather than a value, and each marked state carries
    /// its own symbol — the two are never told apart by colour, which they share.
    private var intentButton: some View {
        Button {
            let next = nextIntent(after: intent)
            if reduceMotion {
                intent = next
            } else {
                withAnimation(Motion.gentleFast) { intent = next }
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 4) {
                if let symbol = intentSymbol {
                    Image(systemName: symbol)
                        .font(.caption.weight(.semibold))
                }
                Text(intentLabel)
                    .font(.subheadline)
                    .fontWeight(intent == nil ? .regular : .medium)
            }
            .foregroundStyle(intent == nil ? Theme.textTertiary : Theme.accent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Was this planned?")
        .accessibilityValue(intentAccessibilityValue)
        .accessibilityHint("Cycles through not marked, impulse, and planned")
    }

    private func nextIntent(after current: SpendIntent?) -> SpendIntent? {
        switch current {
        case nil: .impulse
        case .impulse: .planned
        case .planned: nil
        }
    }

    private var intentLabel: String {
        switch intent {
        case nil: "Impulse?"
        case .impulse: "Impulse"
        case .planned: "Planned"
        }
    }

    /// No glyph while unmarked — the absence is what makes the resting state quiet.
    private var intentSymbol: String? {
        switch intent {
        case nil: nil
        case .impulse: "bolt.fill"
        case .planned: "calendar"
        }
    }

    private var intentAccessibilityValue: String {
        switch intent {
        case nil: "Not marked"
        case .impulse: "Impulse"
        case .planned: "Planned"
        }
    }

    // MARK: - 4. Tile Row

    private func tileRow() -> some View {
        // Derived once per pass and handed down. Reading it inside `tileBody`
        // would redo the whole scan once per tile.
        let states = tileStates
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(topCategories) { category in
                    tileBody(category, state: states[category.key] ?? .noBudget)
                }
                moreTile
            }
            .padding(.horizontal, 24)
        }
    }

    /// Budget state per category, as the three values the tile rule can show.
    ///
    /// The tiles used to carry a tree badge here. A silhouette at 14pt was never
    /// really legible, and five of them beside five emoji made the row the
    /// busiest thing on a screen whose job is one number. A 2pt rule along the
    /// tile's bottom edge says the same thing without adding an object.
    private var tileStates: [String: TileBudgetState] {
        var result: [String: TileBudgetState] = [:]
        for tree in GroveStripModel.trees(categories: categories, entries: activeEntries) {
            result[tree.categoryKey] = tree.isOver ? .over : .within
        }
        return result
    }

    private func tileBody(_ category: SpendCategory, state: TileBudgetState) -> some View {
        let isSelected = selectedCategoryKey == category.key
        return Button {
            selectedCategoryKey = category.key
        } label: {
            VStack(spacing: 4) {
                Text(category.emoji)
                    .font(.title3)
                Text(category.name)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                // The state rule. Drawn for every tile, transparent when there
                // is no budget, so a budgeted and an unbudgeted tile stay
                // exactly the same height and the row never jumps.
                //
                // Inset rather than run to the tile's edges: at the full width
                // the 14pt corner radius clipped both ends and the rule read as
                // a stray dash floating under the label. Pulled in, it reads as
                // something drawn on purpose.
                Rectangle()
                    .fill(state.ruleColor)
                    .frame(height: 2)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 9)
            }
            .frame(width: 62)
            .padding(.top, 12)
            .background(
                isSelected ? Theme.accentSoft : Theme.surface,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(isSelected ? 1.03 : 1)
            .animation(reduceMotion ? nil : Motion.gentleFast, value: isSelected)
        }
        .buttonStyle(.plain)
        // The rule's colour is the only visual difference between a tile within
        // target and one over it, and colour may not carry state on its own.
        // VoiceOver gets the word instead.
        .accessibilityLabel(
            state.spokenSuffix.isEmpty
                ? category.name
                : "\(category.name), \(state.spokenSuffix)"
        )
    }

    /// Matches the tile height exactly. A tile's state rule occupies 10pt of
    /// padding above it, 2pt of rule and 9pt below; "More" has no budget state,
    /// so it pads by that same 21pt rather than drawing a rule it could never
    /// fill. Keep the two in step or the row's tiles stop lining up.
    private var moreTileBottomPadding: CGFloat { 21 }

    /// Opens the full category picker. Labelled "More" rather than "Other" because
    /// "Other" is also a real category that usually sits in the row right beside
    /// this tile — the same word for a category and for the way to reach every
    /// category read as the list simply repeating itself.
    private var moreTile: some View {
        Button {
            showingCategoryPicker = true
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.title3)
                    .fontWeight(.light)
                Text("More")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 62)
            .padding(.top, 12)
            .padding(.bottom, moreTileBottomPadding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 6. Log Button

    private var logButton: some View {
        Button {
            save()
        } label: {
            Text("Log")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: CaptureBottomBar.logButtonHeight)
                .background(
                    canLog ? Theme.accent : Theme.surfaceStrong,
                    in: Capsule()
                )
                .foregroundStyle(canLog ? Color.white : Theme.textTertiary)
        }
        .buttonStyle(PressStyle())
        .disabled(!canLog)
        .padding(.horizontal, 28)
        .padding(.top, CaptureBottomBar.logButtonTopPadding)
    }

    // MARK: - Actions

    private func applyPrefill() {
        guard let prefill else {
            resolveLastUsedCategoryIfNeeded()
            return
        }
        if let amountText = prefill.amountText {
            self.amountText = amountText
        }
        // Always assigned, never merged. The note is the one prefill field with
        // no control on this screen, so a value left over from an earlier
        // activation sits there invisibly and attaches itself to whatever is
        // logged next — a `taplog://log?note=lunch` link followed by an
        // unrelated tap on Log filed a chai as "lunch". The amount above is
        // merged rather than cleared because it *is* visible, and a bare
        // "open the keypad" link should not wipe a number already on screen.
        self.note = prefill.note ?? ""
        if let query = prefill.categoryQuery {
            let lowered = query.lowercased()
            if let match = categories.first(where: {
                $0.key.lowercased() == lowered || $0.name.lowercased() == lowered
            }) {
                selectedCategoryKey = match.key
            } else {
                // The requested category doesn't exist (deleted or renamed) —
                // land on the fallback so the miss is visible instead of
                // silently keeping the previous selection and mis-tagging.
                // Lookup and save render a missing fallback object as "Other".
                selectedCategoryKey = SpendCategory.fallbackKey
            }
        } else {
            resolveLastUsedCategoryIfNeeded()
        }
        onPrefillConsumed?()
    }

    /// A valid deep-link category takes precedence; otherwise preserve the user's
    /// last choice when this screen is opened again.
    private func resolveLastUsedCategoryIfNeeded() {
        guard selectedCategoryKey.isEmpty else { return }
        selectedCategoryKey = categories.first(where: { $0.key == lastUsedCategoryKey })?.key
            ?? categories.first(where: { $0.key != SpendCategory.fallbackKey })?.key
            ?? categories.first?.key
            ?? ""
    }

    private func save() {
        guard let amount = Money.parse(amountText), amount > 0 else { return }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryKey = selectedCategoryKey.isEmpty ? SpendCategory.fallbackKey : selectedCategoryKey
        // Snapshot before the insert. `activeEntries` is a `@Query` and does not
        // refresh inside this function, so the tree's "before" state has to be
        // read from the array as it stands right now — reading it back after the
        // save would be a race against SwiftData's next update.
        let priorEntries = activeEntries

        let entry = Entry(
            amount: amount,
            category: categoryKey,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            intent: intent
        )
        modelContext.insert(entry)
        // `amountText` is deliberately still populated here — it is cleared only
        // after this returns true, so a refusal leaves the user's typed amount
        // on screen to try again with.
        guard EntryPersistence.commit(
            message: EntryPersistence.insertFailureMessage,
            save: { try modelContext.save() },
            rollback: { modelContext.delete(entry) },
            report: undoStack.report
        ) else { return }

        lastUsedCategoryKey = categoryKey
        undoStack.record(
            "Logged \(Money.format(amount)) · \(lookup.name(for: categoryKey))",
            tree: treeConfirmation(for: categoryKey, before: priorEntries, adding: entry)
        ) {
            modelContext.delete(entry)
            do {
                try modelContext.save()
            } catch {
                // The entry is still persisted — counters must stay as they are.
                Log.capture.error("Failed to persist undo of entry: \(Log.describe(error), privacy: .public)")
                return
            }
            CaptureBookkeeping.revert(modelContext: modelContext, categories: categories, categoryKey: categoryKey, entryDate: entry.date)
        }

        CaptureBookkeeping.apply(modelContext: modelContext, categories: categories, categoryKey: categoryKey)
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        amountText = ""
        note = ""
        intent = nil
        amountError = nil
        onLogged?()

        // The second earned moment for the notification prompt: this log just
        // finished a week's target, so there is now a recap worth being told
        // about. `askIfRelevant` is a no-op every other time.
        if retention.targetMet {
            RecapNotifier.shared.askIfRelevant(hasCompletedAWeek: true)
        }
    }

    /// The tree the confirmation shows, or nil when the category has no budget.
    ///
    /// An unbudgeted category deliberately gets nothing: there is no tree, and
    /// drawing one would claim a budget the user never set. Both states come out
    /// of `GroveStripModel.tree` — the same derivation behind the strip and the
    /// tile badges — so the toast cannot word the consequence differently from
    /// the row it is standing under.
    ///
    /// Only this category's own entries are passed, which is what `report` would
    /// have filtered down to anyway, and this runs once per log rather than once
    /// per keypad tap.
    private func treeConfirmation(
        for categoryKey: String,
        before priorEntries: [Entry],
        adding entry: Entry
    ) -> TreeConfirmation? {
        guard let category = categories.first(where: { $0.key == categoryKey }) else { return nil }
        let own = priorEntries.filter { $0.category == categoryKey }
        guard let previous = GroveStripModel.tree(for: category, ownEntries: own),
              let current = GroveStripModel.tree(for: category, ownEntries: own + [entry])
        else { return nil }
        return TreeConfirmation(tree: current, previous: previous)
    }

    private func setAmountError(_ error: String?) {
        if reduceMotion {
            amountError = error
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                amountError = error
            }
        }
    }
}

/// Fixed geometry of the capture screen's pinned bottom bar — the keypad grid
/// plus the Log pill.
///
/// These live outside the view because the undo toast has to float clear of the
/// bar and cannot measure it: the toast is an overlay on the app root, so it
/// sits outside the safe-area inset that holds these controls. The toast used to
/// carry its own hardcoded offset, which was correct when the Log pill was the
/// only thing down here and silently wrong the moment the keypad arrived —
/// "Undo" ended up sitting on the backspace key. Deriving both from the same
/// numbers is what keeps them from drifting apart again.
/// What the 2pt rule under a category tile can say.
///
/// Three states, not six: the tile row answers "is this one fine?" at a glance
/// before the tap. The full six-state tree vocabulary belongs on Budgets, where
/// a drawing has the room to earn the distinction.
enum TileBudgetState {
    case within, over, noBudget

    /// Transparent for an unbudgeted category, so the rule still occupies its
    /// 2pt and every tile in the row keeps the same height.
    var ruleColor: Color {
        switch self {
        case .within:   Theme.accent
        case .over:     Theme.clay
        case .noBudget: .clear
        }
    }

    /// Appended to the tile's spoken label, because the rule's colour cannot
    /// carry the state by itself.
    var spokenSuffix: String {
        switch self {
        case .within:   "within target"
        case .over:     "over target"
        case .noBudget: ""
        }
    }
}

enum CaptureBottomBar {
    static let keyHeight: CGFloat = 56
    static let keySpacing: CGFloat = 10
    static let keyRows: CGFloat = 4
    static let logButtonHeight: CGFloat = 52
    /// Gap between the keypad and the Log pill.
    static let logButtonTopPadding: CGFloat = 8
    /// Extra lift applied to the pill inside the inset stack.
    static let logButtonLiftPadding: CGFloat = 4
    /// Gap between the Log pill and the bottom safe-area edge.
    static let logButtonBottomPadding: CGFloat = 8

    /// Total height of the bar, measured up from the bottom safe-area edge.
    static let height: CGFloat =
        keyHeight * keyRows
        + keySpacing * (keyRows - 1)
        + logButtonTopPadding
        + logButtonLiftPadding
        + logButtonHeight
        + logButtonBottomPadding

    /// Clearance between the top of the bar and the bottom of the undo toast.
    /// It is also how far the toast is allowed to travel as it appears, which is
    /// what keeps the entrance from reaching down over the keys.
    static let toastGap: CGFloat = 10
}
