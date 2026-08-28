import SwiftUI

/// A pull-not-push explainer. Unlike the first-run cover and the deferred
/// prompts in `OnboardingFlow`, nothing here ever interrupts logging: these
/// surfaces live *inside* the feature they describe and are reached by opening
/// it. That keeps the app's "≤5% of interaction time" rule intact — a user who
/// never opens Budgets never sees a word about trees.
struct ExplainerPoint: Identifiable {
    let id = UUID()
    /// SF Symbol drawn when `tree` is nil.
    let symbol: String?
    /// Tree state drawn instead of a symbol, for the budget legend.
    let tree: TreeHealthMark?
    let treeColor: Color?
    /// Streak wreath drawn instead of a symbol — days filled out of a weekly
    /// target. The point that explains the streak shows the mark the user will
    /// actually meet, not a stand-in symbol for it.
    let wreath: (filled: Int, target: Int)?
    let title: String
    let body: String

    init(symbol: String, title: String, body: String) {
        self.symbol = symbol
        self.tree = nil
        self.treeColor = nil
        self.wreath = nil
        self.title = title
        self.body = body
    }

    init(tree: TreeHealthMark, color: Color, title: String, body: String) {
        self.symbol = nil
        self.tree = tree
        self.treeColor = color
        self.wreath = nil
        self.title = title
        self.body = body
    }

    init(wreathFilled: Int, of target: Int, title: String, body: String) {
        self.symbol = nil
        self.tree = nil
        self.treeColor = nil
        self.wreath = (wreathFilled, target)
        self.title = title
        self.body = body
    }
}

/// Sheet listing what a feature does, one point at a time. Deliberately has a
/// single dismiss action — an explainer the user can't leave in one tap is an
/// interruption wearing a different hat.
struct FeatureExplainerView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let subtitle: String
    let points: [ExplainerPoint]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 26)

                    ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                        HStack(alignment: .top, spacing: 16) {
                            explainerIcon(point)
                                .frame(width: 44, height: 52)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(point.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(point.body)
                                    .font(.footnote)
                                    .foregroundStyle(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 12)
                        .entrance(delay: 0.05 * Double(index))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .floatingToolbarScrollEdge()
            .background(Theme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got it") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private func explainerIcon(_ point: ExplainerPoint) -> some View {
        if let tree = point.tree {
            TreeMark(state: tree, color: point.treeColor ?? Theme.accent)
        } else if let wreath = point.wreath {
            WreathMark(daysLogged: wreath.filled, target: wreath.target, color: Theme.accent)
                .frame(width: 40, height: 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let symbol = point.symbol {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Content

extension FeatureExplainerView {

    /// The tree legend. Ordered as a story rather than by severity — plant,
    /// grow, slip, recover — because the point of the metaphor is that the
    /// last two states are recoverable, not terminal.
    static var budgets: FeatureExplainerView {
        FeatureExplainerView(
            title: "Budgets",
            subtitle: "Give a category a weekly or monthly target and it grows a tree. The tree reflects this period and the one before it, so a single bad week never wipes out your history.",
            points: [
                ExplainerPoint(
                    tree: .seedling, color: Theme.accent,
                    title: "Seedling",
                    body: "A new target, or a period with nothing logged yet. Everything starts here."
                ),
                ExplainerPoint(
                    tree: .growing, color: Theme.accent,
                    title: "Growing",
                    body: "Inside your target this period, and last period too. The steady state."
                ),
                ExplainerPoint(
                    tree: .wilting, color: Theme.clay,
                    title: "Wilting",
                    body: "Over target this period after a good one. One slip — the tree thins, it doesn't die."
                ),
                ExplainerPoint(
                    tree: .resting, color: Theme.clay,
                    title: "Resting",
                    body: "Over target two periods running. Bare branches, but the buds are still there."
                ),
                ExplainerPoint(
                    tree: .sprout, color: Theme.accent,
                    title: "Recovering",
                    body: "Back inside your target after going over. This one has to be earned — you have to actually log something."
                ),
                ExplainerPoint(
                    symbol: "arrow.counterclockwise",
                    title: "Changing a target starts over",
                    body: "Past periods stay in your history but stop counting toward the tree, so a new target can't retroactively hand you a growth you never had."
                ),
            ]
        )
    }

    static var recap: FeatureExplainerView {
        FeatureExplainerView(
            title: "Your recap",
            subtitle: "A weekly or monthly read on where the money actually went. Nothing here needs setting up — it fills in as you log.",
            points: [
                ExplainerPoint(
                    symbol: "chart.bar.fill",
                    title: "The total, and the comparison",
                    body: "What you've spent this period, against the last one. The arrow carries the direction; the percentage is unsigned."
                ),
                ExplainerPoint(
                    symbol: "calendar",
                    title: "Week or month",
                    body: "Switch at the top. Monthly budgets are easier to read against a monthly total."
                ),
                ExplainerPoint(
                    symbol: "square.grid.2x2",
                    title: "Day bars",
                    body: "Today is highlighted, days still to come are dimmed. Flat stretches are as informative as spikes."
                ),
                ExplainerPoint(
                    symbol: "tag.fill",
                    title: "By category",
                    body: "Ranked by spend, with each category's share of the total."
                ),
                ExplainerPoint(
                    wreathFilled: 3, of: 5,
                    title: "Streak and freezes",
                    body: "The wreath gains a leaf for each day you log and closes when you hit your weekly target. A freeze covers one missed day so a single slip doesn't reset the count."
                ),
                ExplainerPoint(
                    symbol: "square.and.arrow.up",
                    title: "Export",
                    body: "Every entry as CSV, including archived ones. It's your data — take it whenever you want."
                ),
            ]
        )
    }
}
