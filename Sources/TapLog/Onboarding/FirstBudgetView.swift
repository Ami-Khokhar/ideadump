import SwiftUI
import SwiftData

/// The optional screen that offers to plant the first tree, shown once after the
/// categories beat.
///
/// Budgets are the app's payoff and, until now, the one thing nobody arrived at
/// on their own: a new user logged expenses into a grove that stayed empty
/// because planting a tree meant finding a screen they had no reason to look
/// for. This asks once, about the category they already spend in, and then never
/// asks again.
///
/// It drives `BudgetTargetEditor` — the same control the real budget flow uses —
/// so the tree in the preview is the tree they will actually get, and dialling
/// the target moves it while they watch.
struct FirstBudgetView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SpendCategory.sortOrder) private var categories: [SpendCategory]
    @Query(filter: #Predicate<Entry> { !$0.isArchived && !$0.isPending })
    private var entries: [Entry]

    /// Called when the screen is done with, planted or skipped. The caller
    /// records the dismissal either way — the offer is made once.
    let onDone: () -> Void

    @State private var amount: Decimal = 0
    @State private var period: BudgetPeriod = .weekly
    @State private var errorMessage: String?

    /// The category to offer. Whichever one they have logged most, so the target
    /// is about money they actually spend rather than a category they happen to
    /// have first in the list.
    private var topCategory: SpendCategory? {
        FirstBudgetPick.category(from: categories, entries: entries)
    }

    private var canPlant: Bool {
        topCategory != nil && amount > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let topCategory {
                        headline(for: topCategory)
                        BudgetTargetEditor(
                            categoryKey: topCategory.key,
                            amount: $amount,
                            period: $period
                        )
                    } else {
                        Text("Budgets attach to categories, and there aren't any yet.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
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
            .navigationTitle("Plant a tree")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // One tap out, always available, never buried behind a
                // confirmation. This is an offer, not a step.
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Plant it") { plant() }
                        .fontWeight(.semibold)
                        .disabled(!canPlant)
                }
            }
        }
    }

    private func headline(for category: SpendCategory) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Give \(category.name) a weekly target")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Watch it grow.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func plant() {
        guard let category = topCategory, amount > 0 else { return }

        let original = EditCategorySnapshot(category: category)
        category.budgetTarget = amount
        category.budgetPeriod = period

        do {
            try modelContext.save()
            onDone()
        } catch {
            original.restore(to: category)
            errorMessage = "Could not save: \(error.localizedDescription)"
        }
    }
}

/// Which category the first-budget offer is about.
///
/// Split out from the view so the choice can be tested without a SwiftUI host.
enum FirstBudgetPick {

    /// The most-logged category, falling back to the first in sort order when
    /// nothing has been logged yet. Ties break on `sortOrder` so the offer does
    /// not name a different category each time it is rebuilt.
    static func category(
        from categories: [SpendCategory],
        entries: [Entry]
    ) -> SpendCategory? {
        guard !categories.isEmpty else { return nil }

        var counts: [String: Int] = [:]
        for entry in entries {
            counts[entry.category, default: 0] += 1
        }

        return categories.max { lhs, rhs in
            let left = counts[lhs.key] ?? 0
            let right = counts[rhs.key] ?? 0
            if left != right { return left < right }
            // `max(by:)` keeps the last of equal elements, so the comparison is
            // reversed here to leave the earliest sort order standing.
            return lhs.sortOrder > rhs.sortOrder
        }
    }
}
