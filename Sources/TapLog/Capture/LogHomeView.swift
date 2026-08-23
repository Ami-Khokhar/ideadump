import SwiftUI
import SwiftData
import WidgetKit

/// The capture-first home screen. Minimal — 6 elements, zero clutter.
///
/// Flow: tap tile → type amount → tap Log. Two taps for a daily repeat.
/// One-off: type amount → tap "+ Other" → pick category.
struct LogHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(RetentionManager.self) private var retention
    @EnvironmentObject private var undoStack: UndoStack

    @AppStorage("lastUsedCategory") private var lastUsedCategoryKey: String = SpendCategory.fallbackKey
    @AppStorage("logsLogged") private var logsLogged = 0

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
    @State private var showingManageCategories = false
    @State private var hasFocused = false
    @State private var isCommitting = false
    @State private var rippleBurst = false
    @State private var dropTriggerID = 0
    /// Opening animation state
    @State private var hasAppeared = false
    @FocusState private var amountFocused: Bool

    let isOnboarding: Bool
    let prefill: CapturePrefill?
    let onLogged: (() -> Void)?
    let onCancelOnboarding: (() -> Void)?
    let onPrefillConsumed: (() -> Void)?

    private var lookup: CategoryLookup { CategoryLookup(categories) }

    /// Top 4 categories by usage count (the tiles).
    private var topCategories: [SpendCategory] {
        categories
            .filter { $0.key != SpendCategory.fallbackKey }
            .sorted { $0.logCount > $1.logCount }
            .prefix(4)
            .map { $0 }
    }

    private var todayEntries: [Entry] {
        activeEntries.filter { Calendar.current.isDateInToday($0.date) }
    }
    private var todayTotal: Decimal {
        todayEntries.reduce(Decimal(0)) { $0 + $1.amount }
    }
    private var canLog: Bool {
        guard let amount = Money.parse(amountText) else { return false }
        return amount > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. Status line with mini ring
            statusBar

            Spacer()

            // 2. Amount field (the hero)
            amountArea
                .opacity(hasAppeared ? 1 : 0)
                .scaleEffect(hasAppeared ? 1 : 0.95)
                .animation(.easeOut(duration: 0.5).delay(0.1), value: hasAppeared)

            Spacer()

            // 3. Category + planned line
            categoryLine
                .opacity(hasAppeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.25), value: hasAppeared)

            // 4. Tile grid
            tileRow
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.2), value: hasAppeared)

            // 5. Note field
            noteField
                .opacity(hasAppeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.35), value: hasAppeared)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // 6. Log button
            logButton
                .opacity(hasAppeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.3), value: hasAppeared)
                .padding(.bottom, 12)
                .padding(.top, 4)
        }
        .background(Theme.background)
        .onAppear {
            applyPrefill()
            if !hasFocused {
                hasFocused = true
                amountFocused = true
            }
            withAnimation { hasAppeared = true }
            let args = ProcessInfo.processInfo.arguments
            if let index = args.lastIndex(of: "-autolog"), args.indices.contains(index + 1) {
                let value = args[index + 1]
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    amountText = value
                    save()
                }
            }
        }
        .onChange(of: prefill) { applyPrefill() }
        .sheet(isPresented: $showingManageCategories) {
            CategoryManageView()
        }
    }

    // MARK: - 1. Status Bar (date + today total + mini ring)

    private var statusBar: some View {
        HStack(spacing: 10) {
            // Mini weekly ring
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
        .animation(Motion.stateChange, value: todayTotal)
    }

    /// 16pt ring showing weekly progress,嵌入 status line.
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

    // MARK: - 2. Amount Area (compact, centered, with subtle ripples)

    private var amountArea: some View {
        VStack(spacing: 8) {
            ZStack {
                // Subtle ripple rings behind the amount (much smaller than before)
                RippleView()
                    .frame(width: 120, height: 120)
                    .allowsHitTesting(false)
                DropletView(ambient: true)
                    .frame(width: 120, height: 120)
                DropletView(ambient: false, triggerID: dropTriggerID)
                    .frame(width: 120, height: 120)
                if rippleBurst {
                    RippleView(burst: true)
                        .frame(width: 120, height: 120)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                // Amount input
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(Money.currencySymbol)
                        .font(Theme.amount(28, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(Theme.amount(56))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .focused($amountFocused)
                        .fixedSize(horizontal: true, vertical: false)
                        .tint(Theme.accent)
                }
                .scaleEffect(isCommitting ? 1.06 : 1)
            }
        }
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
                withAnimation(Motion.gentleFast) { isPlanned.toggle() }
            } label: {
                Text(isPlanned ? "Planned" : "Impulse?")
                    .font(.subheadline)
                    .foregroundStyle(isPlanned ? Theme.accent : Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 4. Tile Row (one row of tiles)

    private var tileRow: some View {
        HStack(spacing: 10) {
            ForEach(topCategories) { category in
                tileButton(category)
            }
            otherTile
        }
        .padding(.horizontal, 24)
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
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ? Theme.accentSoft : Theme.surface,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .scaleEffect(isSelected ? 1.03 : 1)
            .animation(Motion.gentleFast, value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private var otherTile: some View {
        Button {
            showingManageCategories = true
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.title3)
                    .fontWeight(.light)
                Text("Other")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
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
        guard let prefill else { return }
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
            }
        }
        if prefill.amountText != nil || prefill.note != nil {
            amountFocused = true
        }
        onPrefillConsumed?()
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
        try? modelContext.save()

        if let cat = categories.first(where: { $0.key == categoryKey }) {
            cat.logCount += 1
            try? modelContext.save()
        }

        lastUsedCategoryKey = categoryKey
        logsLogged += 1
        undoStack.record("Logged \(Money.format(amount)) · \(lookup.name(for: categoryKey))") {
            modelContext.delete(entry)
            try? modelContext.save()
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "SpendWidget")
        retention.recordLogDay()
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(Motion.gentle) { isCommitting = true }
        dropTriggerID += 1
        rippleBurst = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(Motion.gentle) { rippleBurst = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(Motion.gentleFast) {
                isCommitting = false
                amountText = ""
                note = ""
                isPlanned = false
            }
            amountFocused = true
        }

        onLogged?()
    }
}
