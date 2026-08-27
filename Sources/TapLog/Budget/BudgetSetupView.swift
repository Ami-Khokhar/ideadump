import SwiftUI
import SwiftData

/// Sets one category's budget, start to finish, on a single screen.
///
/// Reached from the grove, where the only thing the user came to do is plant a
/// tree — so this flow deliberately exposes nothing about renaming, emoji, or
/// creating categories. Those belong to category management (Menu → Categories).
/// Routing "Set your first budget" through that screen instead put the task three
/// sheets deep behind two titles that never said the word "budget".
///
/// Saving dismisses straight back to the grove, which re-queries and shows the
/// tree that was just planted — the payoff the feature is named for.
struct BudgetSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \SpendCategory.sortOrder) private var categories: [SpendCategory]

    /// Category to open already selected. Set when an existing budget is being
    /// revisited; nil when the user is choosing which category to budget.
    var preselectedKey: String?

    @State private var selectedKey: String?
    @State private var amount: Decimal = 0
    @State private var period: BudgetPeriod = .weekly
    @State private var errorMessage: String?
    @State private var loaded = false

    private var selectedCategory: SpendCategory? {
        guard let selectedKey else { return nil }
        return categories.first { $0.key == selectedKey }
    }

    private var canSave: Bool {
        selectedCategory != nil && amount > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if categories.isEmpty {
                        noCategoriesNotice
                    } else {
                        categorySection
                        targetSection
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Theme.clay)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .floatingToolbarScrollEdge()
            .background(Theme.background)
            .navigationTitle("Set a Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                guard let preselectedKey else { return }
                selectedKey = preselectedKey
                loadExistingBudget(forKey: preselectedKey)
            }
        }
    }

    // MARK: - Category

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Which category?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 74), spacing: 10)],
                spacing: 10
            ) {
                ForEach(categories) { category in
                    categoryTile(category)
                }
            }
        }
    }

    private func categoryTile(_ category: SpendCategory) -> some View {
        let isSelected = selectedKey == category.key
        return Button {
            withAnimation(Motion.gentleFast) {
                selectedKey = category.key
            }
            loadExistingBudget(forKey: category.key)
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
                // A category that already has a target is still selectable — picking
                // it edits that budget rather than silently creating a second one.
                if let subtitle = budgetSubtitle(for: category) {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ? Theme.accentSoft : Theme.surface,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func budgetSubtitle(for category: SpendCategory) -> String? {
        guard let target = category.budgetTarget, target > 0, let period = category.budgetPeriod else {
            return nil
        }
        return "\(Money.format(target)) / \(period == .monthly ? "mo" : "wk")"
    }

    // MARK: - Target

    @ViewBuilder
    private var targetSection: some View {
        if let selectedCategory {
            VStack(alignment: .leading, spacing: 12) {
                Text("How much per period?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                BudgetTargetEditor(
                    categoryKey: selectedCategory.key,
                    amount: $amount,
                    period: $period
                )
            }
            .transition(.opacity)
        } else {
            Text("Pick a category to give it a weekly or monthly target.")
                .font(.footnote)
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private var noCategoriesNotice: some View {
        Text("Budgets attach to categories, and there aren't any yet. Add one from Menu → Categories, then come back.")
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Actions

    /// Switching category switches which budget is being edited, so the controls
    /// adopt that category's existing target — or reset to "None" if it has none.
    private func loadExistingBudget(forKey key: String) {
        guard let category = categories.first(where: { $0.key == key }) else { return }
        if let target = category.budgetTarget, target > 0, let existingPeriod = category.budgetPeriod {
            amount = target
            period = existingPeriod
        } else {
            amount = 0
            period = .weekly
        }
    }

    private func save() {
        guard let category = selectedCategory, amount > 0 else { return }

        let original = EditCategorySnapshot(category: category)
        category.budgetTarget = amount
        category.budgetPeriod = period

        do {
            try modelContext.save()
            dismiss()
        } catch {
            original.restore(to: category)
            errorMessage = "Could not save: \(error.localizedDescription)"
        }
    }
}
