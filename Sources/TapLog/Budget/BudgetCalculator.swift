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
    /// interval, and confirmed (neither pending share-sheet import nor archived).
    static func activeEntries(
        _ entries: [Entry],
        matching key: String,
        in interval: Interval
    ) -> [Entry] {
        entries.filter { entry in
            entry.category == key
                && !entry.isPending
                && !entry.isArchived
                && interval.contains(entry.date)
        }
    }

    // MARK: - Totals

    /// Decimal-safe sum of `entries`. Empty input is zero — never nil — so callers
    /// can always subtract from a target without unwrapping.
    static func total(of entries: [Entry]) -> Decimal {
        entries.reduce(Decimal(0)) { $0 + $1.amount }
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
        let currentMatches = activeEntries(entries, matching: category.key, in: brackets.current)
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
