import SwiftUI
import SwiftData

/// The capture-first home screen. Minimal — 6 elements, zero clutter.
///
/// Flow: tap tile → type amount → tap Log. Two taps for a daily repeat.
/// One-off: type amount → tap "+ Other" → pick category.
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
    @State private var isPlanned = false
    @State private var showingCategoryPicker = false
    @State private var showingManageCategories = false
    @State private var hasFocused = false
    @State private var amountError: String?
    /// Opening animation: 0 = logo visible, 1 = content visible
    @State private var openingPhase: CGFloat = 0
    @FocusState private var amountFocused: Bool

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
            if !hasFocused {
                hasFocused = true
                amountFocused = true
            }
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
                amountFocused = true
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
                    amountFocused = true
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

    private var mainContent: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    statusBar
                    Spacer(minLength: geometry.size.height < 650 ? 8 : 20)
                    amountArea
                    Spacer(minLength: geometry.size.height < 650 ? 8 : 20)
                    categoryLine
                    tileRow
                    noteField
                }
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                logButton
                    .padding(.bottom, 8)
                    .padding(.top, 4)
            }
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

    private var amountArea: some View {
        VStack(spacing: 8) {
            if amountText.isEmpty && !amountFocused {
                Text("Type the amount, tap Log.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textTertiary)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: amountFocused)
            }
            GeometryReader { geometry in
                let fontSize = AmountFont.fontSize(for: amountText, dynamicTypeSize: dynamicTypeSize)
                let fieldHeight = AmountLayout.fieldHeight(fontSize: fontSize)
                let symbolWidth = (Money.currencySymbol as NSString).size(
                    withAttributes: [.font: UIFont.systemFont(ofSize: fontSize * 0.5, weight: .semibold)]
                ).width
                let maxFieldWidth = max(44, geometry.size.width - symbolWidth - 34)
                let fieldWidth = AmountLayout.fieldWidth(
                    text: amountText,
                    fontSize: fontSize,
                    maxWidth: maxFieldWidth
                )
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Money.currencySymbol)
                        .font(AmountFont.symbolFont(for: amountText, dynamicTypeSize: dynamicTypeSize))
                        .foregroundStyle(Theme.textTertiary)
                        .accessibilityHidden(true)
                    AmountTextField(
                        text: $amountText,
                        isFocused: $amountFocused,
                        fontSize: fontSize,
                        minimumFontSize: AmountLayout.minimumFontSize(
                            text: amountText,
                            fontSize: fontSize,
                            availableWidth: fieldWidth
                        ),
                        onErrorChanged: { error in setAmountError(error) }
                    )
                    .frame(width: fieldWidth, height: fieldHeight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .frame(height: AmountLayout.heroHeight(fontSize: AmountFont.fontSize(
                for: amountText,
                dynamicTypeSize: dynamicTypeSize
            )))

            if let error = amountError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - 3. Category + Planned Line

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

            Button {
                if reduceMotion {
                    isPlanned.toggle()
                } else {
                    withAnimation(Motion.gentleFast) { isPlanned.toggle() }
                }
            } label: {
                Text(isPlanned ? "Planned" : "Impulse?")
                    .font(.subheadline)
                    .foregroundStyle(isPlanned ? Theme.accent : Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 4. Tile Row

    private var tileRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(topCategories) { category in
                    tileButton(category)
                }
                otherTile
            }
            .padding(.horizontal, 24)
        }
    }

    private func tileButton(_ category: SpendCategory) -> some View {
        let isSelected = selectedCategoryKey == category.key
        return Button {
            selectedCategoryKey = category.key
            amountFocused = true
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

    private var otherTile: some View {
        Button {
            showingCategoryPicker = true
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.title3)
                    .fontWeight(.light)
                Text("Other")
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
                .frame(height: 52)
                .background(
                    canLog ? Theme.accent : Theme.surfaceStrong,
                    in: Capsule()
                )
                .foregroundStyle(canLog ? Color.white : Theme.textTertiary)
        }
        .buttonStyle(ZenPress())
        .disabled(!canLog)
        .padding(.horizontal, 28)
        .padding(.top, 8)
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
                resolveLastUsedCategoryIfNeeded()
            }
        } else {
            resolveLastUsedCategoryIfNeeded()
        }
        if prefill.amountText != nil || prefill.note != nil {
            amountFocused = true
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
            isPlanned: isPlanned
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
        isPlanned = false
        amountFocused = true

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
