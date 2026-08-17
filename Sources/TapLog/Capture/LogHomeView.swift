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
            statusLine
            Spacer(minLength: 10)
            hero
            categoryChips
            noteField
        }
        // Pin the Log button in the bottom safe area so it always floats ABOVE the
        // keyboard. Without this, the button (the last element) is pushed underneath
        // the keyboard on a real device and logging becomes impossible.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            logButton
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
            Text("Today · ")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .monospacedDigit()
            + Text(Money.format(todayTotal))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, 28)
        .padding(.top, 16)
    }

    private var hero: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Money.currencySymbol)
                    .font(Theme.amount(44, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(Theme.amount(84))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .focused($amountFocused)
                    .fixedSize(horizontal: true, vertical: false)
                    .tint(Theme.accent)
            }
            .frame(maxWidth: .infinity)

            Text(isOnboarding
                ? "Your first expense — type the amount, tap Log. About 5 seconds."
                : "Type the amount, tap Log. About 5 seconds.")
                .font(.subheadline)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 4)
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
        .buttonStyle(.plain)
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
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        amountText = ""
        note = ""
        amountFocused = true

        onLogged?()
    }
}
