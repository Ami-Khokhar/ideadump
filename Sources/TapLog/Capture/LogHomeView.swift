import SwiftUI
import SwiftData
import WidgetKit

/// The capture-first home screen. This is the default tab — the amount field is the
/// hero and logging happens in place, never behind a "+" tap. History is one tab away.
///
/// Also serves as onboarding Step 1 (`isOnboarding`): shows a coaching header instead
/// of the plain caption, and `onLogged` advances the flow instead of just clearing.
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
    )
    private var activeEntries: [Entry]

    @State private var amountText = ""
    @State private var selectedCategoryKey = ""
    @State private var note = ""
    @State private var showingManageCategories = false
    @State private var hasFocused = false
    /// Briefly true right after a log — the hero amount settles into the ledger
    /// (a soft pulse) before the field clears.
    @State private var isCommitting = false
    /// Triggers the on-log ripple burst.
    @State private var rippleBurst = false
    /// Fires a new drop on each increment.
    @State private var dropTriggerID = 0
    @FocusState private var amountFocused: Bool

    let isOnboarding: Bool
    let prefill: CapturePrefill?
    let onLogged: (() -> Void)?
    let onCancelOnboarding: (() -> Void)?
    /// Lets the owner clear the consumed deep-link prefill so it isn't re-injected
    /// the next time the home view reappears (e.g. after closing a sheet).
    let onPrefillConsumed: (() -> Void)?

    private var lookup: CategoryLookup { CategoryLookup(categories) }

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
            Spacer(minLength: 12)
            heroStone.entrance(delay: 0.10)
            categoryChips.entrance(delay: 0.20)
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
            // Dev/testing hook: `simctl launch ... -autolog 12.50` logs an expense
            // shortly after launch, exercising the exact save path headlessly.
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

    // MARK: - Sections

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
        .padding(.trailing, 40)  // avoid overlap with the menu button
        .animation(Motion.stateChange, value: todayTotal)
    }

    /// Weekly ring + streak — sits between the status line and the zen stone.
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

    /// The hero amount inside a zen stone — a soft circle with ambient ripples.
    private var heroStone: some View {
        VStack(spacing: 16) {
            ZStack {
                // Ambient ripple rings behind the stone.
                RippleView()
                    .frame(width: 260, height: 260)
                    .allowsHitTesting(false)
                // Ambient droplet — drips every ~5s like a zen water feature.
                DropletView(ambient: true)
                    .frame(width: 260, height: 260)
                // On-log droplet — fires a single drop on save.
                DropletView(ambient: false, triggerID: dropTriggerID)
                    .frame(width: 260, height: 260)
                // On-log burst (fires once, then resets).
                if rippleBurst {
                    RippleView(burst: true)
                        .frame(width: 260, height: 260)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
                // The stone itself.
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Money.currencySymbol)
                            .font(Theme.amount(36, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(Theme.amount(72))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .focused($amountFocused)
                            .fixedSize(horizontal: true, vertical: false)
                            .tint(Theme.accent)
                    }
                    .scaleEffect(isCommitting ? 1.06 : 1)
                }
                .frame(width: 240, height: 240)
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
                                        endRadius: 120
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
                    radius: 20, x: 0, y: 8
                )
            }

            Text(isOnboarding
                ? "Your first expense — type the amount, tap Log."
                : "Type the amount, tap Log.")
                .font(.subheadline)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories) { category in
                    chip(category)
                }
                addChip
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 6)
        }
    }

    private func chip(_ category: SpendCategory) -> some View {
        let isSelected = selectedCategoryKey == category.key
        return Button {
            selectedCategoryKey = category.key
        } label: {
            VStack(spacing: 4) {
                Text(category.emoji)
                    .font(.title3)
                    .grayscale(isSelected ? 0 : 0.15)
                Text(category.name)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                    .fontWeight(isSelected ? .semibold : .medium)
            }
            .frame(minWidth: 62)
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .background(
                isSelected ? Theme.accentSoft : Theme.surface,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
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
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.title3)
                    .fontWeight(.light)
                    .foregroundStyle(Theme.textTertiary)
                Text("Add")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(minWidth: 62)
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var noteField: some View {
        TextField("Note (optional)", text: $note)
            .multilineTextAlignment(.center)
            .font(.body)
            .padding(.vertical, 10)
            .padding(.horizontal, 30)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(height: 1)
                    .padding(.horizontal, 30)
            }
    }

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
        .padding(.top, 14)
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
        // Consumed: the owner clears it so it never re-applies on a later appear.
        onPrefillConsumed?()
    }

    private func save() {
        guard let amount = Money.parse(amountText), amount > 0 else { return }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryKey = selectedCategoryKey.isEmpty ? SpendCategory.fallbackKey : selectedCategoryKey

        let entry = Entry(
            amount: amount,
            category: categoryKey,
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )
        modelContext.insert(entry)
        try? modelContext.save()
        lastUsedCategoryKey = categoryKey
        logsLogged += 1
        undoStack.record("Logged \(Money.format(amount)) · \(lookup.name(for: categoryKey))") {
            modelContext.delete(entry)
            try? modelContext.save()
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "SpendWidget")
        retention.recordLogDay()
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // The hero settles into the ledger: a soft pulse + ripple burst, then the field clears.
        withAnimation(Motion.gentle) { isCommitting = true }
        // Fire the drop + ripple burst — drop falls, then splash.
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
            }
            amountFocused = true
        }

        onLogged?()
    }
}
