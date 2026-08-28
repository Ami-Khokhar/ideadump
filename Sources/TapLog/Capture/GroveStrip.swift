import SwiftUI

/// One budgeted category, reduced to what the capture screen needs to show it.
///
/// A value type on purpose: the strip and the category tiles are rebuilt on every
/// keypad tap, and comparing five of these is far cheaper than re-deriving them
/// from SwiftData models each time.
struct GroveTree: Identifiable, Equatable {
    let categoryKey: String
    let name: String
    let health: BudgetCalculator.TreeHealth
    /// "₹40 left this week" / "₹120 over this week" — the same sentence the
    /// Budgets screen writes under the row, so the two screens agree word for word.
    let detail: String
    /// Share of the target already spent. Kept so the strip can lead with the
    /// budget under the most pressure, matching how Budgets orders its rows.
    let utilization: Decimal

    var id: String { categoryKey }

    var mark: TreeHealthMark { TreeHealthMark(health) }

    /// True when this period's spend is past the target. Derived from the state
    /// rather than carried separately: `wilting` and `resting` are exactly the
    /// two states `BudgetCalculator` can reach with `currentSpent > target`, and
    /// the other three are exactly the ones it reaches within target.
    var isOver: Bool { health == .wilting || health == .resting }

    /// Colour is never the only difference between two states — the silhouettes
    /// differ too — but the tint still has to follow the same rule the Budgets
    /// screen uses so a tree doesn't change colour between screens.
    var tint: Color { isOver ? Theme.clay : Theme.accent }

    /// The same tint chosen for the undo toast, which is the one surface in the
    /// app whose ground is inverted — see `Theme.toastAccent`.
    var toastTint: Color { isOver ? Theme.toastClay : Theme.toastAccent }

    /// Names the category and the state, because the drawing alone is not
    /// available to VoiceOver: "Chai, over this period, ₹120 over this week".
    var accessibilityLabel: String {
        let word = BudgetsView.stateWord(for: health)
        return word.isEmpty ? "\(name), \(detail)" : "\(name), \(word), \(detail)"
    }
}

/// Pure derivation of the capture screen's grove. Kept out of the view so the
/// rules that decide whether the strip appears at all — and in what order — are
/// testable without standing up SwiftUI.
enum GroveStripModel {

    /// Trees the strip will draw before it runs out of room next to the caption.
    /// Budgets past this are still counted in the summary; they are just not
    /// drawn, which is the honest trade for keeping this to one short line.
    static let maxStripTrees = 5

    /// Every budgeted category as a tree, most pressed against its target first
    /// so an overspend is always among the ones that fit.
    ///
    /// The entries are bucketed by category in one pass before any report is
    /// built. `BudgetCalculator.report` scans the whole array twice — current
    /// period and previous — so calling it per category walked every entry
    /// 2 × *budgets* times, and each step of that walk is a SwiftData property
    /// read. Measured in a Debug build at 2,000 entries and 8 budgets, that cost
    /// ~20ms; this screen rebuilds on every keypad tap, so it had to come down.
    /// Bucketing first is exact rather than an approximation: `report` only ever
    /// counts entries whose category matches, so handing it that category's own
    /// slice cannot change its answer.
    static func trees(
        categories: [SpendCategory],
        entries: [Entry],
        calendar: Calendar = .current,
        referenceDate: Date = .now
    ) -> [GroveTree] {
        let budgeted = categories.filter { ($0.budgetTarget ?? 0) > 0 && $0.budgetPeriod != nil }
        // Nobody has a budget: the strip is hidden anyway, so don't touch the
        // entries at all. This is the fresh-install path and it must be free.
        guard !budgeted.isEmpty else { return [] }

        let budgetedKeys = Set(budgeted.map(\.key))
        var entriesByCategory: [String: [Entry]] = [:]
        for entry in entries where budgetedKeys.contains(entry.category) {
            entriesByCategory[entry.category, default: []].append(entry)
        }

        return budgeted
            .compactMap {
                tree(
                    for: $0,
                    ownEntries: entriesByCategory[$0.key] ?? [],
                    calendar: calendar,
                    referenceDate: referenceDate
                )
            }
            .sorted {
                // Ties break on the key so the row never reshuffles itself
                // between redraws — two untouched budgets both sit at zero.
                $0.utilization == $1.utilization
                    ? $0.categoryKey < $1.categoryKey
                    : $0.utilization > $1.utilization
            }
    }

    /// One category's tree, built from that category's own entries.
    ///
    /// `ownEntries` is the slice the bucketing above produces — and `report`
    /// only ever counts entries whose category matches, so a caller with a
    /// single category in hand can hand it that category's entries directly and
    /// get the same answer. Nil for an unbudgeted or half-configured category,
    /// which is what lets callers tell "no tree" from "a tree at zero".
    ///
    /// Every tree in the app is built here, so the state, the tint and the
    /// sentence under it cannot drift apart between the strip, the tiles and the
    /// log confirmation.
    static func tree(
        for category: SpendCategory,
        ownEntries: [Entry],
        calendar: Calendar = .current,
        referenceDate: Date = .now
    ) -> GroveTree? {
        guard let report = BudgetCalculator.report(
            for: category,
            entries: ownEntries,
            calendar: calendar,
            referenceDate: referenceDate
        ) else { return nil }
        let cadence = report.period == .monthly ? "month" : "week"
        return GroveTree(
            categoryKey: category.key,
            name: category.name,
            health: report.health,
            detail: BudgetsView.statusText(for: report, cadence: cadence),
            utilization: report.utilization ?? 0
        )
    }

    /// The caption beside the trees.
    ///
    /// With a single budget the strip can afford the whole truth — "Chai · ₹40
    /// left this week" — which is more use than counting to one, and it names the
    /// tree standing next to it, which nothing else on this row does. Past that
    /// it is a split, phrased shorter than the Budgets screen's own caption
    /// because this line shares a row with the trees rather than owning one.
    static func summary(for trees: [GroveTree]) -> String {
        guard let only = trees.first else { return "" }
        guard trees.count > 1 else { return "\(only.name) · \(only.detail)" }
        let over = trees.filter(\.isOver).count
        return over == 0 ? "All within target" : "\(over) over target"
    }

    /// One spoken sentence for the whole row: VoiceOver gets the state of every
    /// tree, including any the row was too narrow to draw.
    static func accessibilityLabel(for trees: [GroveTree]) -> String {
        (["Your grove"] + trees.map(\.accessibilityLabel)).joined(separator: ". ")
    }
}

/// A glanceable row of the user's budget trees, sitting under the capture
/// screen's status line and opening the Budgets screen when tapped.
///
/// The trees are the app's whole idea, and until now they lived two taps deep
/// behind a `⋯` menu — so the capture screen looked like every other expense
/// logger. This puts them where they are seen without asking for them, at the
/// cost of one short line, and without moving the keypad or the Log button:
/// those are pinned to the bottom inset and never share space with this.
struct GroveStrip: View {
    let trees: [GroveTree]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                HStack(alignment: .bottom, spacing: 7) {
                    ForEach(trees.prefix(GroveStripModel.maxStripTrees)) { tree in
                        TreeStateGlyph(state: tree.mark, color: tree.tint)
                            .frame(width: 24, height: 30)
                    }
                }

                Spacer(minLength: 8)

                Text(GroveStripModel.summary(for: trees))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(ZenPress())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GroveStripModel.accessibilityLabel(for: trees))
        .accessibilityHint("Opens Budgets")
    }
}
