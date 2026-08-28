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
    @State private var note = ""
    /// nil until the user answers — see `intentButton`.
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
        let keys = TimeBucket.blendedTopCategories(
            entries: activeEntries,
            categories: categories,
            maxSlots: 4
        )
        return keys.compactMap { key in
            categories.first { $0.key == key }
        }
    }

    private var todayEntries: [Entry] {
        activeEntries.filter { Calendar.current.isDateInToday($0.date) }
    }
    private var todayTotal: Decimal {
        todayEntries.reduce(Decimal(0)) { $0 + $1.amount }
    }
    private var canLog: Bool {
        AmountInputFilter.isValid(amountText)
    }

    var body: some View {
        ZStack {
            // Background
            Theme.background.ignoresSafeArea()

            // Logo (fades out as content fades in)
            logoView
                .opacity(1 - openingPhase)
                .ignoresSafeArea()

            // Main content (fades in)
            mainContent
                .opacity(openingPhase)
        }
        .onAppear {
            applyPrefill()
            if skipSplash || reduceMotion {
                // Intent launch — skip straight to capture, no logo delay.
                openingPhase = 1
            } else {
                // Fade transition: logo holds for 1.0s, then smoothly dissolves to content over 0.8s
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.spring(response: 0.8, dampingFraction: 1.0)) {
                        openingPhase = 1
                    }
                }
            }
            let args = ProcessInfo.processInfo.arguments
            if let index = args.lastIndex(of: "-autolog"), args.indices.contains(index + 1) {
                let value = args[index + 1]
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    amountText = value
                    save()
                }
            }
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

    // MARK: - Logo (animated)

    private var logoView: some View {
        AnimatedLogoView()
    }

    // MARK: - Main Content

    /// The keypad and Log button are pinned as a bottom inset so the two controls
    /// that finish the task are always under the thumb, whatever the screen height.
    /// Everything above them scrolls, which is what keeps this usable on a 4.7"
    /// device where the keypad alone claims most of the viewport.
    private var mainContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                statusBar
                Spacer(minLength: 20)
                amountArea
                Spacer(minLength: 20)
                categoryLine
                tileRow
                noteField
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                keypad
                logButton
                    .padding(.bottom, CaptureBottomBar.logButtonBottomPadding)
                    .padding(.top, CaptureBottomBar.logButtonLiftPadding)
            }
            .background(Theme.background)
        }
    }

    // MARK: - 1. Status Bar

    private var statusBar: some View {
        HStack(spacing: 10) {
            miniRing

            Text(Date.now.formatted(.dateTime.weekday(.abbreviated)))
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)

            Spacer()

            if isOnboarding {
                Button {
                    onCancelOnboarding?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            (Text("Today · ")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .monospacedDigit()
            + Text(Money.format(todayTotal))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit())
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.trailing, 40)
        .animation(reduceMotion ? nil : Motion.stateChange, value: todayTotal)
    }

    private var miniRing: some View {
        ZStack {
            Circle()
                .stroke(Theme.surfaceStrong, lineWidth: 2.5)
                .frame(width: 16, height: 16)
            Circle()
                .trim(from: 0, to: retention.ringFraction)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(-90))
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
            if amountText.isEmpty {
                Text("Use the keypad, then Log.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textTertiary)
                    .transition(.opacity)
            }

            let fontSize = AmountFont.fontSize(for: amountText, dynamicTypeSize: dynamicTypeSize)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Money.currencySymbol)
                    .font(AmountFont.symbolFont(for: amountText, dynamicTypeSize: dynamicTypeSize))
                    .foregroundStyle(Theme.textTertiary)
                    .accessibilityHidden(true)
                Text(amountText.isEmpty ? "0" : amountText)
                    .font(Theme.amount(fontSize))
                    .foregroundStyle(amountText.isEmpty ? Theme.textTertiary : Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
            }
            .frame(height: AmountLayout.heroHeight(fontSize: fontSize))
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
        .buttonStyle(ZenPress())
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

    // MARK: - 3. Category + Intent Line

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
    /// most contested one-line strip on the screen and a third option would either
    /// widen it or shrink the category name; and — more importantly — the happy
    /// path must stay untouched. Unmarked is the resting state, so logging is
    /// still amount → Log with no detour, and the control costs a tap only when
    /// the user chooses to answer.
    ///
    /// The order answers the question the resting label asks. "Impulse?" is an
    /// invitation, so the first tap says yes; the second corrects it to Planned;
    /// the third takes the answer back. Unmarked stays tertiary and glyph-less so
    /// it reads as a prompt rather than a value, and each marked state carries its
    /// own symbol — the two are never told apart by colour, which they share.
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

    private var tileRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(topCategories) { category in
                    tileButton(category)
                }
                moreTile
            }
            .padding(.horizontal, 24)
        }
    }

    private func tileButton(_ category: SpendCategory) -> some View {
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
            }
            .frame(width: 62)
            .padding(.vertical, 12)
            .background(
                isSelected ? Theme.accentSoft : Theme.surface,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .scaleEffect(isSelected ? 1.03 : 1)
            .animation(reduceMotion ? nil : Motion.gentleFast, value: isSelected)
        }
        .buttonStyle(.plain)
    }

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
            .padding(.vertical, 12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 5. Note Field

    private var noteField: some View {
        TextField("Note (optional)", text: $note)
            .multilineTextAlignment(.center)
            .font(.subheadline)
            .foregroundStyle(Theme.textTertiary)
            .padding(.vertical, 6)
            .padding(.horizontal, 40)
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
        .buttonStyle(ZenPress())
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
        if let note = prefill.note {
            self.note = note
        }
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
        if prefill.amountText != nil || prefill.note != nil {
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

        let entry = Entry(
            amount: amount,
            category: categoryKey,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            intent: intent
        )
        modelContext.insert(entry)
        do {
            try modelContext.save()
        } catch {
            print("TapLog: Failed to save entry: \(error)")
            modelContext.delete(entry)
            return
        }

        lastUsedCategoryKey = categoryKey
        undoStack.record("Logged \(Money.format(amount)) · \(lookup.name(for: categoryKey))") {
            modelContext.delete(entry)
            do {
                try modelContext.save()
            } catch {
                // The entry is still persisted — counters must stay as they are.
                print("TapLog: Failed to persist undo of entry: \(error)")
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
}
