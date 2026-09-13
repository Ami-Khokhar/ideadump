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

    @State private var showingExplainer = false
    @State private var showingBudgetSetup = false
    @State private var showingPaywall = false

    private var pro = ProStore.shared

    /// Budgets that actually exist, which is what the free limit counts. Derived
    /// from the same reports the grove draws, so the number the gate sees is the
    /// number of trees the user can see.
    private var budgetCount: Int { budgetReports.count }

    private var budgetReports: [BudgetCalculator.Report] {
        categories
            .compactMap { BudgetCalculator.report(for: $0, entries: entries) }
            .sorted {
                // Tie-break on the key, matching `GroveStripModel.trees`. Sort
                // order is not stable, and the grove card above now draws only
                // the first few — so without this, which of several untouched
                // budgets (all sitting at zero) get drawn could change between
                // redraws of the same unchanged data.
                ($0.utilization ?? 0) == ($1.utilization ?? 0)
                    ? $0.categoryKey < $1.categoryKey
                    : ($0.utilization ?? 0) > ($1.utilization ?? 0)
            }
    }

    /// `budgetReports` reduced to the shape `GroveSceneModel` expects, in the
    /// same most-pressed-first order. This is the one conversion point, so the
    /// header scene and the per-row species below are always derived from the
    /// same list.
    private var groveTrees: [GroveTree] {
        budgetReports.map { report in
            let cadence = report.period == .monthly ? "month" : "week"
            return GroveTree(
                categoryKey: report.categoryKey,
                name: lookup.name(for: report.categoryKey),
                health: report.health,
                detail: Self.statusText(for: report, cadence: cadence),
                utilization: report.utilization ?? 0
            )
        }
    }

    /// Plants for the header grove. This screen has room for the full strip,
    /// unlike the capture screen's `GroveStripModel.maxStripTrees` cap.
    private var grovePlants: [GrovePlant] {
        GroveSceneModel.plants(from: groveTrees, maxPlants: 7)
    }

    /// Keyed by category so a row can look up the exact plant the header drew
    /// for it — same species, same tint — instead of re-deriving one.
    private var grovePlantsByCategory: [String: GrovePlant] {
        Dictionary(uniqueKeysWithValues: grovePlants.map { ($0.categoryKey, $0) })
    }

    var body: some View {
        NavigationStack {
            Group {
                if budgetReports.isEmpty {
                    emptyState
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
                    .floatingToolbarScrollEdge()
                    .background(PaperGround())
                }
            }
            .navigationTitle("Budgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingExplainer = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("What the trees mean")
                }
                // Only offered once the grove exists: the empty state already has a
                // full-width call to action, and two "add" affordances on one screen
                // would compete rather than help.
                if !budgetReports.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            // The paywall stands in front of the *next* tree, never
                            // in front of the ones already growing.
                            if ProGate.canPlantAnotherTree(
                                existingBudgetCount: budgetCount,
                                isPro: pro.isPro
                            ) {
                                showingBudgetSetup = true
                            } else {
                                showingPaywall = true
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add a budget")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingExplainer) {
                FeatureExplainerView.budgets
                    .applyAppearanceOverride()
                    .tint(Theme.accent)
            }
            .sheet(isPresented: $showingBudgetSetup) {
                BudgetSetupView()
                    .applyAppearanceOverride()
                    .tint(Theme.accent)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(reason: .anotherTree)
                    .applyAppearanceOverride()
                    .tint(Theme.accent)
            }
        }
    }

    // MARK: - Empty State

    /// The empty state *is* the budgets onboarding: it names the idea, shows the
    /// three trees the metaphor turns on, and hands over the action. The previous
    /// version told the user to "set a target on any category" and then offered no
    /// way to do it — the screen that asks for a budget must also be able to open
    /// the place budgets are set.
    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: 18) {
                    TreeMark(state: .seedling, color: Theme.accent)
                        .frame(width: 52, height: 65)
                    TreeMark(state: .growing, color: Theme.accent)
                        .frame(width: 68, height: 85)
                    TreeMark(state: .wilting, color: Theme.clay)
                        .frame(width: 52, height: 65)
                }
                .padding(.top, 36)
                .entrance()

                Text("Budgets grow trees")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 26)
                    .entrance(delay: 0.08)

                Text("Give a category a weekly or monthly target and it grows a tree that reflects how you're doing. Go over and it thins out — it never dies.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 34)
                    .padding(.top, 10)
                    .entrance(delay: 0.14)

                Button {
                    showingBudgetSetup = true
                } label: {
                    Text("Set your first budget")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.accent, in: Capsule())
                        .foregroundStyle(Color.white)
                }
                .buttonStyle(PressStyle())
                .padding(.horizontal, 28)
                .padding(.top, 30)
                .entrance(delay: 0.2)

                Button("How the trees work") { showingExplainer = true }
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 16)
                    .entrance(delay: 0.24)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 40)
        }
        .floatingToolbarScrollEdge()
        .background(PaperGround())
    }

    // MARK: - Grove Band

    private var groveCard: some View {
        let groveSummary = computeGroveSummary()
        return VStack(alignment: .leading, spacing: 0) {
            // The full grove scene, expanded. This is the one place on the app
            // where the grove gets to be big — every budgeted category up to
            // `GroveSceneModel`'s default cap, laid out on real ground instead
            // of the capture screen's cramped strip. `GroveScene` carries its
            // own single VoiceOver summary, so nothing here adds a second one.
            GroveScene(plants: grovePlants)
                .frame(height: 180)
                .frame(maxWidth: .infinity)

            // No divider here on purpose. `GroveScene` already draws its own
            // ground line across the full width, so a hairline underneath it
            // put two parallel rules a few points apart and read as a mistake.
            // The ground line is the divider.
            Text(groveSummary)
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 8)

        }
        .padding(.all, 16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Groups the six health states into the two things a glance actually asks:
    /// how many trees are inside their target, and how many are past it. Naming
    /// each state here would pluralise badly ("2 sprouts, 1 seedlings") and say
    /// less than the split does.
    ///
    /// The wording is deliberately *not* a tree state. This line used to read
    /// "1 growing" over a single tree the row below labelled "New" — "Growing"
    /// is one specific state in the legend, so using it as a headcount claimed a
    /// state the grove didn't have. "Within target" and "over target" describe
    /// the split without borrowing a name from the legend.
    private func computeGroveSummary() -> String {
        var withinTarget = 0
        var overTarget = 0
        for report in budgetReports {
            switch report.health {
            case .seedling, .sprout, .growing: withinTarget += 1
            case .wilting, .resting: overTarget += 1
            case .noBudget: break
            }
        }
        var parts: [String] = []
        if withinTarget > 0 { parts.append("\(withinTarget) within target") }
        if overTarget > 0 { parts.append("\(overTarget) over target") }
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
        // Same plant the header grove drew for this category, so the row's
        // species always matches. Falls back to the plain mark when a budget
        // sits past the header's plant cap.
        let plant = grovePlantsByCategory[report.categoryKey]

        return VStack(alignment: .leading, spacing: 0) {
            // Main row
            Button {
                withAnimation(Motion.gentle) {
                    expandedCategory = isExpanded ? nil : report.categoryKey
                }
            } label: {
                HStack(spacing: 12) {
                    // Tree mark — species-matched to the header grove when available.
                    Group {
                        if let plant {
                            SpeciesTreeMark(
                                state: TreeHealthMark(report.health),
                                species: plant.species,
                                color: report.isOver ? Theme.clay : Theme.accent
                            )
                        } else {
                            TreeMark(
                                state: TreeHealthMark(report.health),
                                color: report.isOver ? Theme.clay : Theme.accent
                            )
                        }
                    }
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
            .buttonStyle(PressStyle())
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
        .padding(.horizontal, 12)
        .organicBackground(.tile, seed: report.categoryKey, fill: Theme.surface)
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
