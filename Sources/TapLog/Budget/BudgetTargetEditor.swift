import SwiftUI
import SwiftData
import UIKit

/// The budget half of a category: target stepper, reset cadence, and a live tree
/// preview of what that target would mean right now. Extracted from the category
/// editor so the dedicated budget flow and category management drive the same
/// control rather than two copies that drift apart.
///
/// The preview deliberately does not go through `BudgetCalculator.report(for:)` —
/// that reads the *persisted* target and period, and this has to answer "what will
/// this budget do?" for the values the user is currently dialling.
struct BudgetTargetEditor: View {
    /// Category the preview measures spend against. An unknown or empty key simply
    /// previews against zero spend, so callers can render the control before the
    /// user has committed to a category.
    let categoryKey: String
    @Binding var amount: Decimal
    @Binding var period: BudgetPeriod

    @State private var previewState: TreeHealthMark = .noBudget

    /// The amount exactly as the field shows it. Kept alongside `amount` instead
    /// of derived from it so a half-typed "1 2 ." survives the trip through
    /// Decimal — `syncTextFromAmount` only rewrites it when the two disagree.
    @State private var amountText = ""
    @FocusState private var amountFocused: Bool

    @Query(filter: #Predicate<Entry> { !$0.isArchived && !$0.isPending }, sort: \Entry.date)
    private var entries: [Entry]

    /// Step size follows the cadence, so a weekly and a monthly target take a
    /// similar number of taps to dial in.
    private var step: Decimal {
        BudgetCalculator.step(for: period)
    }

    /// The picker writes through this rather than binding `$period` directly, so a
    /// cadence switch can carry the amount with it. Doing the conversion in
    /// `onChange(of: period)` instead would also fire when the caller swaps in
    /// another category's saved budget, re-scaling a target that was already right.
    private var periodSelection: Binding<BudgetPeriod> {
        Binding(
            get: { period },
            set: { newPeriod in
                guard newPeriod != period else { return }
                amount = BudgetCalculator.convertTarget(amount, from: period, to: newPeriod)
                period = newPeriod
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepperRow

            Picker("Resets", selection: periodSelection) {
                Text("Weekly").tag(BudgetPeriod.weekly)
                Text("Monthly").tag(BudgetPeriod.monthly)
            }
            .pickerStyle(.segmented)

            previewCard

            Text("Changing the target starts the tree over; past periods stay in history but stop counting toward this tree.")
                .font(.footnote)
                .foregroundStyle(Theme.textTertiary)
        }
        .onAppear {
            syncTextFromAmount()
            updatePreview()
        }
        // The preview follows every input that feeds it: the amount, the cadence
        // (which changes both the step size and the interval spend is summed over),
        // and the category the caller is pointing this control at.
        .onChange(of: amount) { _, _ in
            syncTextFromAmount()
            updatePreview()
        }
        .onChange(of: amountText) { _, newValue in applyTypedText(newValue) }
        .onChange(of: period) { _, _ in updatePreview() }
        .onChange(of: categoryKey) { _, _ in updatePreview() }
    }

    // MARK: - Stepper

    private var stepperRow: some View {
        HStack(spacing: 12) {
            stepperButton(systemName: "minus", label: "Decrease budget") {
                amount = max(0, amount - step)
            }

            // Typing beats 32 taps for a realistic target like ₹8,000/month, so the
            // amount is the same editable field the capture screen uses. Its own
            // filter rejects anything unparseable, and `applyTypedText` clamps what
            // survives, so the error callback has nothing left to report here.
            AmountTextField(
                text: $amountText,
                isFocused: $amountFocused,
                placeholder: "None",
                fontSize: 38,
                minimumFontSize: 24,
                textColor: UIColor(Theme.textPrimary),
                tintColor: UIColor(Theme.accent),
                textAlignment: .center,
                showsDoneAccessory: true,
                onErrorChanged: { _ in }
            )
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .onTapGesture { amountFocused = true }

            stepperButton(systemName: "plus", label: "Increase budget") {
                amount = min(BudgetCalculator.maxTarget, amount + step)
            }
        }
        .frame(height: 52)
    }

    /// Mirrors typed text into the bound amount. Blank or unparseable input reads
    /// as "no budget" — the same thing stepping down to zero means — so the
    /// control can never strand the user in a state Save would reject.
    private func applyTypedText(_ text: String) {
        let parsed = Money.parse(text) ?? 0
        let clamped = min(BudgetCalculator.maxTarget, max(0, parsed))
        if clamped != amount {
            amount = clamped
        }
        // Typed past the cap: correct what's on screen too, so the number the user
        // reads is the number that gets saved.
        if clamped != parsed {
            amountText = Money.plainString(clamped)
        }
    }

    /// Pushes stepper- and picker-driven changes back into the field, but only
    /// when the field doesn't already say the same thing — rewriting it on every
    /// keystroke would fight the caret mid-entry.
    private func syncTextFromAmount() {
        guard (Money.parse(amountText) ?? 0) != amount else { return }
        amountText = amount > 0 ? Money.plainString(amount) : ""
    }

    private func stepperButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 52, height: 52)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Preview

    private var previewCard: some View {
        HStack(spacing: 16) {
            TreeMark(state: previewState, color: treeColor(for: previewState))
                .frame(width: 60, height: 75)

            VStack(alignment: .leading, spacing: 4) {
                Text(stateWord(for: previewState))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(treeColor(for: previewState))
                Text(stateExplanation(for: previewState, spent: previewSpend))
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .transition(.opacity)
    }

    /// Spend in the period the user is *currently choosing*, not the one last saved.
    private var previewSpend: Decimal {
        let now = Date.now
        let brackets = BudgetCalculator.intervals(for: period, calendar: .current, referenceDate: now)
        let matches = BudgetCalculator.activeEntries(
            entries, matching: categoryKey, in: brackets.current, notAfter: now
        )
        return BudgetCalculator.total(of: matches)
    }

    private func updatePreview() {
        guard amount > 0 else {
            withAnimation(Motion.gentle) {
                previewState = .noBudget
            }
            return
        }

        let spent = previewSpend

        let state: TreeHealthMark
        if spent > amount {
            state = .wilting
        } else if amount >= spent * 3 {
            state = .growing
        } else {
            state = .sprout
        }

        withAnimation(Motion.gentle) {
            previewState = state
        }
    }

    private func treeColor(for state: TreeHealthMark) -> Color {
        switch state {
        case .wilting:
            return Theme.clay
        case .noBudget:
            return Theme.textTertiary
        default:
            return Theme.accent
        }
    }

    private func stateWord(for state: TreeHealthMark) -> String {
        switch state {
        case .noBudget:
            return "No budget"
        case .wilting:
            let cadence = period == .monthly ? "month" : "week"
            return "Over this \(cadence)"
        case .growing:
            return "Steady"
        case .sprout:
            return "Recovering"
        default:
            return "Growing"
        }
    }

    private func stateExplanation(for state: TreeHealthMark, spent: Decimal) -> String {
        switch state {
        case .noBudget:
            return "This category will still log normally, it just won't grow a tree."
        case .wilting:
            let overspent = spent - amount
            return "You've spent \(Money.format(overspent)) over the budget."
        case .growing:
            return "This is a comfortable target — great pace."
        case .sprout:
            let remaining = amount - spent
            return "Recover this period by staying within the remaining \(Money.format(remaining))."
        default:
            return "Your spending is on track."
        }
    }
}
