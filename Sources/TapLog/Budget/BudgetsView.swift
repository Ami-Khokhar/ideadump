import SwiftUI
import SwiftData

/// A full-page budget dashboard presented as a sheet. Shows all configured category
/// budgets — those with both a positive target and a reset period — sorted by
/// proximity to limit so overspends and high-utilization budgets surface first.
/// Each row animates drawer expansion for period-over-period comparison, and a
/// summary grove band shows the aggregate health across all categories.
struct BudgetsView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Entry> { !$0.isArchived && !$0.isPending }, sort: \Entry.date)
    private var entries: [Entry]

    @Query(sort: \SpendCategory.sortOrder)
    private var categories: [SpendCategory]

    @State private var expandedCategory: String?

    private var lookup: CategoryLookup { CategoryLookup(categories) }

    private var budgetReports: [BudgetCalculator.Report] {
        categories
            .compactMap { BudgetCalculator.report(for: $0, entries: entries) }
            .sorted {
                ($0.utilization ?? 0) > ($1.utilization ?? 0)
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if budgetReports.isEmpty {
                    ContentUnavailableView(
                        "No budgets yet",
                        systemImage: "leaf",
                        description: Text("Set a target on any category to start growing a tree.")
                    )
                    .background(Theme.background)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Grove band
                            groveCard
                                .padding(.horizontal, 24)
                                .padding(.top, 24)

                            // Budget rows
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(budgetReports, id: \.categoryKey) { report in
                                    budgetRowWithDrawer(report)
                                    Rectangle()
                                        .fill(Theme.hairline)
                                        .frame(height: 1)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .padding(.bottom, 40)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Theme.background)
                }
            }
            .navigationTitle("Budgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Grove Band

    private var groveCard: some View {
        let groveSummary = computeGroveSummary()
        return VStack(alignment: .leading, spacing: 0) {
            // Trees in a row
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(budgetReports, id: \.categoryKey) { report in
                    VStack(spacing: 0) {
                        TreeMark(
                            state: TreeHealthMark(report.health),
                            color: report.isOver ? Theme.clay : Theme.accent
                        )
                        .frame(width: 48, height: 60)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            // Divider
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
                .padding(.top, 12)

            // Caption
            Text(groveSummary)
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 8)

        }
        .padding(.all, 16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Groups the six health states into the two things a glance actually asks:
    /// how many trees are alive and growing, and how many are over their target.
    /// Naming each state here would pluralise badly ("2 sprouts, 1 seedlings")
    /// and say less than the split does.
    private func computeGroveSummary() -> String {
        var growing = 0
        var over = 0
        for report in budgetReports {
            switch report.health {
            case .seedling, .sprout, .growing: growing += 1
            case .wilting, .resting: over += 1
            case .noBudget: break
            }
        }
        var parts: [String] = []
        if growing > 0 { parts.append("\(growing) growing") }
        if over > 0 { parts.append("\(over) over budget") }
        return parts.isEmpty ? "" : parts.joined(separator: " · ")
    }

    // MARK: - Copy

    /// Plain-language name for a tree state. Deliberately non-clinical: the states
    /// exist to encourage, so even chronic overspend reads as "Resting", not a failure.
    static func stateWord(for health: BudgetCalculator.TreeHealth) -> String {
        switch health {
        case .seedling: return "New"
        case .sprout:   return "Recovering"
        case .growing:  return "Steady"
        case .wilting:  return "Over this period"
        case .resting:  return "Resting"
        case .noBudget: return ""
        }
    }

    static func statusText(for report: BudgetCalculator.Report, cadence: String) -> String {
        report.isOver
            ? "\(Money.format(-report.remaining)) over this \(cadence)"
            : "\(Money.format(report.remaining)) left this \(cadence)"
    }

    // MARK: - Budget Rows

    private func budgetRowWithDrawer(_ report: BudgetCalculator.Report) -> some View {
        let isExpanded = expandedCategory == report.categoryKey
        let cadence = report.period == .monthly ? "month" : "week"
        let utilization = NSDecimalNumber(decimal: report.utilization ?? 0).doubleValue

        return VStack(alignment: .leading, spacing: 0) {
            // Main row
            Button {
                withAnimation(Motion.gentle) {
                    expandedCategory = isExpanded ? nil : report.categoryKey
                }
            } label: {
                HStack(spacing: 12) {
                    // Tree mark
                    TreeMark(
                        state: TreeHealthMark(report.health),
                        color: report.isOver ? Theme.clay : Theme.accent
                    )
                    .frame(width: 42, height: 53)

                    VStack(alignment: .leading, spacing: 6) {
                        // Name and amount row
                        HStack {
                            Text(lookup.name(for: report.categoryKey))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text("\(Money.format(report.currentSpent)) / \(Money.format(report.target))")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                                .monospacedDigit()
                        }

                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Theme.surfaceStrong)
                                Capsule()
                                    .fill(report.isOver ? Theme.clay : Theme.accent)
                                    .frame(width: max(4, geometry.size.width * min(1, utilization)))
                            }
                        }
                        .frame(height: 5)

                        // Status caption
                        let stateWord = Self.stateWord(for: report.health)
                        let statusText = Self.statusText(for: report, cadence: cadence)

                        HStack(spacing: 4) {
                            if !stateWord.isEmpty {
                                Text(stateWord)
                                    .foregroundStyle(report.isOver ? Theme.clay : Theme.accent)
                                Text("·")
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Text(statusText)
                                .foregroundStyle(report.isOver ? Theme.clay : Theme.textSecondary)
                        }
                        .font(.caption)
                        .monospacedDigit()
                    }
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(ZenPress())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel(for: report))

            // Expandable drawer
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.top, 4)

                    // Current period bar
                    HStack(spacing: 12) {
                        Text("This \(cadence)")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 60, alignment: .leading)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Theme.surfaceStrong)
                                let currentFraction = NSDecimalNumber(
                                    decimal: report.target > 0 ? report.currentSpent / report.target : 0
                                ).doubleValue
                                Capsule()
                                    .fill(report.isOver ? Theme.clay : Theme.accent)
                                    .frame(width: max(2, geometry.size.width * min(1, currentFraction)))
                            }
                        }
                        .frame(height: 4)

                        Text(Money.format(report.currentSpent))
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .monospacedDigit()
                            .frame(width: 60, alignment: .leading)
                    }

                    // Previous period bar or incomparable message
                    if report.previousPeriodIsComparable {
                        HStack(spacing: 12) {
                            Text("Last \(cadence)")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 60, alignment: .leading)

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Theme.surfaceStrong)
                                    let previousFraction = NSDecimalNumber(
                                        decimal: report.target > 0 ? report.previousSpent / report.target : 0
                                    ).doubleValue
                                    Capsule()
                                        .fill(report.previousSpent > report.target ? Theme.clay : Theme.textTertiary)
                                        .frame(width: max(2, geometry.size.width * min(1, previousFraction)))
                                }
                            }
                            .frame(height: 4)

                            Text(Money.format(report.previousSpent))
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .monospacedDigit()
                                .frame(width: 60, alignment: .leading)
                        }
                    } else {
                        Text("Budget changed — earlier periods aren't compared.")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 10)
    }

    private func accessibilityLabel(for report: BudgetCalculator.Report) -> String {
        let cadence = report.period == .monthly ? "month" : "week"
        let name = lookup.name(for: report.categoryKey)
        let current = Money.format(report.currentSpent)
        let target = Money.format(report.target)

        if report.isOver {
            let over = Money.format(-report.remaining)
            return "\(name): \(current) of \(target) per \(cadence). \(over) over."
        } else {
            let left = Money.format(report.remaining)
            return "\(name): \(current) of \(target) per \(cadence). \(left) left."
        }
    }
}
