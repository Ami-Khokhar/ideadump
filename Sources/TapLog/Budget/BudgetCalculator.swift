import Foundation

/// Pure, side-effect-free math for category budgets. Every function takes an
/// explicit `Calendar` and reference date so it stays deterministic in tests and
/// matches the user's locale settings when called from the UI layer.
enum BudgetCalculator {

    // MARK: - Interval derivation

    /// A budget period bracket, expressed as a half-open `[start, end)` range.
    /// The previous interval is always exactly one period before the current one.
    struct Interval: Equatable, Sendable {
        let start: Date
        let end: Date
        let period: BudgetPeriod

        /// Whether `date` falls inside this interval.
        func contains(_ date: Date) -> Bool {
            date >= start && date < end
        }
    }

    /// Returns the current and previous budget intervals for the given `period`,
    /// anchored at `referenceDate`. The reset cadence comes from the `period`
    /// parameter directly, so callers can compute intervals without reading
    /// persisted state.
    static func intervals(
        for period: BudgetPeriod,
        calendar: Calendar = .current,
        referenceDate: Date = .now
    ) -> (current: Interval, previous: Interval) {
        let unit: Calendar.Component = (period == .weekly) ? .weekOfYear : .month
        let currentStart = calendar.dateInterval(of: unit, for: referenceDate)?.start
            ?? referenceDate
        let currentEnd = calendar.date(byAdding: unit, value: 1, to: currentStart)
            ?? currentStart
        let previousStart = calendar.date(byAdding: unit, value: -1, to: currentStart)
            ?? currentStart
        let previousEnd = currentStart
        return (
            Interval(start: currentStart, end: currentEnd, period: period),
            Interval(start: previousStart, end: previousEnd, period: period)
        )
    }

    /// Returns the current and previous budget intervals for `category`, anchored
    /// at `referenceDate`. The reset cadence comes from `category.budgetPeriod`,
    /// which `report(for:)` requires to be set alongside a positive target — there
    /// is deliberately no silent weekly fallback.
    static func intervals(
        for category: SpendCategory,
        calendar: Calendar = .current,
        referenceDate: Date = .now
    ) -> (current: Interval, previous: Interval) {
        // `budgetPeriod` is the sole source of the reset cadence. Callers that
        // pass an unbudgeted category get a weekly bracket as a harmless default;
        // `report(for:)` never does, since it requires a configured period first.
        let period: BudgetPeriod = category.budgetPeriod ?? .weekly
        return intervals(for: period, calendar: calendar, referenceDate: referenceDate)
    }

    // MARK: - Filtering

    /// Entries that count toward a budget total: matching category, inside the
    /// interval, confirmed (neither pending share-sheet import nor archived),
    /// and already spent.
    ///
    /// `notAfter` is the cut-off the recap already applies. An entry dated
    /// tomorrow sits inside the current week or month, so without it the money
    /// was subtracted from the remaining budget before it had been spent — and
    /// a far-enough-forward date could tip a healthy tree to wilting for a
    /// purchase that hasn't happened. It defaults to `.distantFuture` so a
    /// caller asking about a fully elapsed interval need not supply one; the
    /// previous bracket is always in the past, and passing a cut-off there
    /// would be a no-op.
    static func activeEntries(
        _ entries: [Entry],
        matching key: String,
        in interval: Interval,
        notAfter: Date = .distantFuture
    ) -> [Entry] {
        entries.filter { entry in
            entry.category == key
                && !entry.isPending
                && !entry.isArchived
                && interval.contains(entry.date)
                && entry.date <= notAfter
        }
    }

    // MARK: - Totals

    /// Decimal-safe sum of `entries`. Empty input is zero — never nil — so callers
    /// can always subtract from a target without unwrapping.
    static func total(of entries: [Entry]) -> Decimal {
        entries.reduce(Decimal(0)) { $0 + $1.amount }
    }

    // MARK: - Targets

    /// Largest target the editor accepts. Well past any real category budget, and
    /// small enough that the amount still renders on one line.
    static let maxTarget: Decimal = 999_999

    /// Stepper increment for a cadence. Weekly and monthly targets live on
    /// different grids so either one takes a similar number of taps to dial in.
    /// It is only the `−`/`+` step: typed and converted amounts are never snapped
    /// onto it, so an exact target the user chose stays exact.
    static func step(for period: BudgetPeriod) -> Decimal {
        period == .weekly ? 50 : 250
    }

    /// A month averages 52 ÷ 12 ≈ 4.33 weeks — the honest ratio between the two
    /// cadences, rather than the "4 weeks" that would quietly shrink a budget.
    private static let weeksPerMonth = Decimal(52) / Decimal(12)

    /// Re-expresses a target in a different cadence, preserving what the user
    /// actually chose: how much they may spend over time.
    ///
    /// Switching the picker used to leave the number alone, so ₹50/week silently
    /// became ₹50/month — a 4.3× cut to a figure the user deliberately set. The
    /// amount is therefore scaled proportionally and kept exact: ₹50/week becomes
    /// ₹216.67/month. Rounding that to a "tidier" ₹250 would be the same class of
    /// silent rewrite this function exists to prevent.
    ///
    /// Zero passes through untouched — "no budget" means the same thing in both
    /// cadences, and there is no allowance to preserve.
    static func convertTarget(
        _ amount: Decimal,
        from source: BudgetPeriod,
        to destination: BudgetPeriod
    ) -> Decimal {
        guard source != destination, amount > 0 else { return amount }

        let scaled = destination == .monthly
            ? amount * weeksPerMonth
            : amount / weeksPerMonth

        // Convert exactly rather than snapping to the stepper's increment. The
        // amount is the user's number; rounding ₹34,666.67 up to ₹34,750 hands
        // them a target they never chose, which is the same silent rewrite the
        // conversion exists to prevent. Two places is currency precision and
        // stops 52/12 leaving a repeating tail.
        var rounded = Decimal()
        var unrounded = scaled
        NSDecimalRound(&rounded, &unrounded, 2, .plain)

        return min(maxTarget, rounded)
    }

    // MARK: - Report

    /// Compact, non-moralizing health for a budget. The tree metaphor stays
    /// alive in every state — even chronic overspend is "resting", not dead —
    /// because the point is encouragement, not judgment.
    enum TreeHealth: Equatable, Sendable {
        /// The category has no target configured — there is no tree to track.
        case noBudget
        /// Current period in budget, no prior context (a fresh start).
        case seedling
        /// Current period in budget after a prior overspend — recovery / new growth.
        case sprout
        /// Current period in budget, prior period also in budget — steady growth.
        case growing
        /// Current period overspent, prior period in budget — wilting but not lost.
        case wilting
        /// Current and prior both overspent — resting, never dead.
        case resting
    }

    /// Aggregated output for a single category's budget. All monetary fields are
    /// non-negative Decimals except `remaining`, which is positive when under
    /// budget and negative when over.
    struct Report: Equatable, Sendable {
        let categoryKey: String
        let period: BudgetPeriod?
        let current: Interval
        let previous: Interval
        let target: Decimal
        let currentSpent: Decimal
        let previousSpent: Decimal
        let currentCount: Int
        let previousCount: Int
        /// Whether the previous interval was fully evaluated under the current
        /// budget configuration. A reset during that interval makes it historical
        /// context only; its raw totals remain available above.
        let previousPeriodIsComparable: Bool

        /// Target minus current spend. Positive = under budget, zero = exactly at,
        /// negative = overspent.
        var remaining: Decimal { target - currentSpent }

        /// `currentSpent / target`, computed with exact Decimal division so the
        /// result is not skewed by Double conversion. Nil when there's no positive
        /// target so UI code can distinguish "not configured" from "exactly zero".
        var utilization: Decimal? {
            guard target > 0 else { return nil }
            return currentSpent / target
        }

        /// True when current spend strictly exceeds the target.
        var isOver: Bool { currentSpent > target }

        /// True when current spend is less than or equal to the target —
        /// overspending means strictly exceeding it.
        var isWithin: Bool { currentSpent <= target }

        /// True when previous spend strictly exceeded the target.
        var wasPreviouslyOver: Bool {
            previousPeriodIsComparable && previousSpent > target
        }

        var health: TreeHealth {
            guard period != nil, target > 0 else { return .noBudget }
            switch (isWithin, wasPreviouslyOver) {
            case (true,  true):
                // Recovery is only real if something was actually logged this
                // period; an empty current period says nothing about behavior.
                return currentCount > 0 ? .sprout : .growing
            case (true,  false):
                return previousPeriodIsComparable && previousCount > 0 ? .growing : .seedling
            case (false, true):  return .resting   // chronic but alive
            case (false, false): return .wilting   // one bad period
            }
        }
    }

    /// Builds a full budget report for `category`. Returns nil unless the category
    /// has both a positive target and an explicitly configured period — a target
    /// without a reset cadence is an incomplete budget, so callers can
    /// short-circuit UI for unbudgeted or half-configured categories.
    static func report(
        for category: SpendCategory,
        entries: [Entry],
        calendar: Calendar = .current,
        referenceDate: Date = .now
    ) -> Report? {
        guard let target = category.budgetTarget, target > 0,
              category.budgetPeriod != nil else { return nil }
        let brackets = intervals(for: category, calendar: calendar, referenceDate: referenceDate)
        let currentMatches = activeEntries(
            entries, matching: category.key, in: brackets.current, notAfter: referenceDate
        )
        let previousMatches = activeEntries(entries, matching: category.key, in: brackets.previous)
        let previousPeriodIsComparable = category.budgetHealthResetDate.map {
            $0 <= brackets.previous.start
        } ?? true
        return Report(
            categoryKey: category.key,
            period: category.budgetPeriod,
            current: brackets.current,
            previous: brackets.previous,
            target: target,
            currentSpent: total(of: currentMatches),
            previousSpent: total(of: previousMatches),
            currentCount: currentMatches.count,
            previousCount: previousMatches.count,
            previousPeriodIsComparable: previousPeriodIsComparable
        )
    }
}
