import SwiftUI
import SwiftData
import WidgetKit

/// The capture-first home screen. Two modes of logging:
///
/// 1. **Tile tap** — tap a category tile, type amount, Log. Covers ~80% of daily logs.
/// 2. **Amount first** — type amount, pick category (or leave uncategorised), Log.
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
    @FocusState private var amountFocused: Bool

    let isOnboarding: Bool
    let prefill: CapturePrefill?
    let onLogged: (() -> Void)?
    let onCancelOnboarding: (() -> Void)?
    let onPrefillConsumed: (() -> Void)?

    private var lookup: CategoryLookup { CategoryLookup(categories) }

    /// Categories sorted by usage frequency (most-used first).
    private var sortedCategories: [SpendCategory] {
        categories.sorted { $0.logCount > $1.logCount }
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
            statusLine.entrance()
            weeklyRingRow.entrance(delay: 0.04)
            Spacer(minLength: 8)
            tileGrid.entrance(delay: 0.08)
            Spacer(minLength: 8)
            heroStone.entrance(delay: 0.14)
            plannedToggle.entrance(delay: 0.18)
            categoryChips.entrance(delay: 0.22)
            noteField.entrance(delay: 0.26)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            logButton
                .entrance(delay: 0.30)
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

    // MARK: - Status Line

    private var statusLine: some View {
        HStack {
            Text(Date.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
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
        .padding(.horizontal, 28)
        .padding(.top, 16)
        .padding(.trailing, 40)
        .animation(Motion.stateChange, value: todayTotal)
    }

    // MARK: - Weekly Ring

    private var weeklyRingRow: some View {
        HStack(spacing: 12) {
            WeeklyRingView(
                progress: retention.ringFraction,
                daysLogged: retention.daysLoggedThisWeek,
                target: retention.weeklyTarget,
                freezesAvailable: retention.streakFreezes
            )
            VStack(alignment: .leading, spacing: 2) {
                if let streak = retention.streakDescription {
                    Text("🔥 \(streak)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                } else {
                    Text("Log this week")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                Text("\(retention.weeklyTarget) days/week target")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Tile Grid

    private var tileGrid: some View {
        TileGrid(
            selectedCategoryKey: $selectedCategoryKey,
            amountText: $amountText,
            amountFocused: $amountFocused,
            onAddTile: { showingManageCategories = true }
        )
    }

    // MARK: - Hero Stone

    private var heroStone: some View {
        VStack(spacing: 12) {
            ZStack {
                RippleView()
                    .frame(width: 220, height: 220)
                    .allowsHitTesting(false)
                DropletView(ambient: true)
                    .frame(width: 220, height: 220)
                DropletView(ambient: false, triggerID: dropTriggerID)
                    .frame(width: 220, height: 220)
                if rippleBurst {
                    RippleView(burst: true)
                        .frame(width: 220, height: 220)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Money.currencySymbol)
                            .font(Theme.amount(32, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(Theme.amount(64))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .focused($amountFocused)
                            .fixedSize(horizontal: true, vertical: false)
                            .tint(Theme.accent)
                    }
                    .scaleEffect(isCommitting ? 1.06 : 1)
                }
                .frame(width: 200, height: 200)
                .background {
                    Circle()
                        .fill(Theme.surface)
                        .overlay {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.white.opacity(colorScheme == .dark ? 0.03 : 0.06),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 100
                                    )
                                )
                        }
                        .clipShape(Circle())
                }
                .clipShape(Circle())
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(0.4)
                        : Color.black.opacity(0.06),
                    radius: 16, x: 0, y: 6
                )
            }

            if selectedCategoryKey.isEmpty {
                Text("Tap a tile or type the amount")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
            } else {
                Text("\(lookup.emoji(for: selectedCategoryKey)) \(lookup.name(for: selectedCategoryKey))")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Planned / Impulse Toggle

    private var plannedToggle: some View {
        Button {
            withAnimation(Motion.gentleFast) { isPlanned.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isPlanned ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                Text(isPlanned ? "Planned" : "Impulse?")
                    .font(.caption)
            }
            .foregroundStyle(isPlanned ? Theme.accent : Theme.textTertiary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isPlanned ? Theme.accentSoft : Theme.surface,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category Chips (frequency-sorted)

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(sortedCategories) { category in
                    chip(category)
                }
                addChip
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 4)
        }
    }

    private func chip(_ category: SpendCategory) -> some View {
        let isSelected = selectedCategoryKey == category.key
        return Button {
            selectedCategoryKey = category.key
        } label: {
            VStack(spacing: 3) {
                Text(category.emoji)
                    .font(.caption)
                    .grayscale(isSelected ? 0 : 0.15)
                Text(category.name)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                    .fontWeight(isSelected ? .semibold : .medium)
            }
            .frame(minWidth: 54)
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .background(
                isSelected ? Theme.accentSoft : Theme.surface,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .scaleEffect(isSelected ? 1.05 : 1)
            .animation(Motion.gentleFast, value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private var addChip: some View {
        Button {
            showingManageCategories = true
        } label: {
            VStack(spacing: 3) {
                Image(systemName: "plus")
                    .font(.caption)
                    .fontWeight(.light)
                    .foregroundStyle(Theme.textTertiary)
                Text("Add")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(minWidth: 54)
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Note Field

    private var noteField: some View {
        TextField("Note (optional)", text: $note)
            .multilineTextAlignment(.center)
            .font(.body)
            .padding(.vertical, 8)
            .padding(.horizontal, 30)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(height: 1)
                    .padding(.horizontal, 30)
            }
    }

    // MARK: - Log Button

    private var logButton: some View {
        Button {
            save()
        } label: {
            Text("Log")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    canLog ? Theme.accent : Theme.surfaceStrong,
                    in: Capsule()
                )
                .foregroundStyle(canLog ? Color.white : Theme.textTertiary)
        }
        .buttonStyle(ZenPress())
        .disabled(!canLog)
        .padding(.horizontal, 28)
        .padding(.top, 10)
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

        // Update category log count for tile frequency sorting.
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
