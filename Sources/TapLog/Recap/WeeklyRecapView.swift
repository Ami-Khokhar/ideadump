import SwiftUI
import SwiftData

/// Recap timespan selection: week or month.
enum RecapSpan: String, CaseIterable {
    case week
    case month

    var title: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        }
    }
}

struct WeeklyRecapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RetentionManager.self) private var retention
    @AppStorage("logsLogged", store: StoreLocator.sharedDefaults) private var logsLogged = 0
    @AppStorage("recapTeaseDismissed") private var recapTeaseDismissed = false

    @Query(filter: #Predicate<Entry> { !$0.isArchived && !$0.isPending }, sort: \Entry.date)
    private var entries: [Entry]

    @Query(filter: #Predicate<Entry> { !$0.isPending }, sort: \Entry.date)
    private var exportEntries: [Entry]

    @Query(sort: \SpendCategory.sortOrder)
    private var categories: [SpendCategory]

    /// Set true on first appear so the bars grow up from the baseline once.
    @State private var barsGrown = false
    @State private var showingExplainer = false

    /// Current recap timespan selection.
    @State private var span: RecapSpan = .week

    private var lookup: CategoryLookup { CategoryLookup(categories) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with title and span toggle
                HStack {
                    Text("Recap")
                        .font(.title2.weight(.bold))
                    Spacer()
                    spanToggle
                }
                .padding(.horizontal, 28)
                .padding(.top, 16)
                .padding(.bottom, 12)

                if logsLogged >= 5 && !recapTeaseDismissed {
                    recapTeaseBanner
                }
                recapContent
            }
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingExplainer = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("How to read this recap")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingExplainer) {
                FeatureExplainerView.recap
                    .applyAppearanceOverride()
            }
            .onAppear {
                // Let the sheet settle before the bars rise.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    barsGrown = true
                }
                RecapNotifier.shared.recordRecapOpened()
            }
            .onDisappear {
                // Asked on the way out, not on the way in: the user has now seen
                // what a recap is, and the one system prompt we get is not spent
                // on top of the thing they came here to read.
                RecapNotifier.shared.askIfRelevant(hasCompletedAWeek: retention.targetMet)
            }
        }
    }

    // MARK: - Header controls

    private var spanToggle: some View {
        HStack(spacing: 4) {
            ForEach(RecapSpan.allCases, id: \.self) { option in
                Button {
                    withAnimation(Motion.gentleFast) {
                        span = option
                    }
                } label: {
                    Text(option.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            span == option ? Theme.textPrimary : Theme.textSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(
                            span == option
                                ? Theme.background
                                : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(ZenPress())
            }
        }
        .padding(4)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    // MARK: - Recap content

    private var recapContent: some View {
        // Compute data based on selected span
        let (thisData, lastData, dayBars, barLabels) = span == .week
            ? computeWeekData()
            : computeMonthData()

        let thisTotals = totals(byCategory: thisData)
        let thisTotal = thisData.reduce(Decimal(0)) { $0 + $1.amount }
        let lastTotal = lastData.reduce(Decimal(0)) { $0 + $1.amount }
        let spanTitle = span == .week ? "This week" : "This month"
        let compareTitle = span == .week ? "last week" : "last month"
        let thisIntent = RecapMath.intentBreakdown(thisData)
        let lastIntent = RecapMath.intentBreakdown(lastData)
        let categoryIntents = RecapMath.intentBreakdown(byCategory: thisData)

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if thisData.isEmpty {
                    emptySpanState
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(spanTitle)
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .entrance()
                        Text(Money.format(thisTotal))
                            .font(Theme.amount(46))
                            .foregroundStyle(Theme.textPrimary)
                            .contentTransition(.numericText())
                            .entrance(delay: 0.08)
                        if thisTotal != lastTotal {
                            if lastTotal > 0 {
                                // Guard against near-zero baselines producing absurd percentages
                                let pct = (thisTotal - lastTotal) / lastTotal
                                if pct > 9.99 {
                                    // Clamp: percentage > 999%, show no number
                                    let up = thisTotal > lastTotal
                                    Text("\(up ? "▲" : "▼") vs. \(compareTitle)")
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(up ? Theme.accent : Theme.textSecondary)
                                        .monospacedDigit()
                                } else {
                                    // Normal case: show percentage
                                    let up = thisTotal > lastTotal
                                    // The arrow already carries the direction, so the
                                    // percentage is shown unsigned — "▼ -36%" reads as
                                    // a double negative.
                                    Text("\(up ? "▲" : "▼") \(Money.percent(abs(pct))) vs. \(compareTitle)")
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(up ? Theme.accent : Theme.textSecondary)
                                        .monospacedDigit()
                                }
                            } else {
                                // First period tracked
                                Text("First \(span == .week ? "week" : "month") tracked")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        } else {
                            Text("\(Money.format(lastTotal)) \(compareTitle)")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 24)
                    .animation(Motion.stateChange, value: thisTotal)

                    // Bars
                    HStack(alignment: .bottom, spacing: 8) {
                        let maxBar = max(dayBars.max() ?? 1, 1)
                        let barCount = dayBars.count
                        ForEach(0..<barCount, id: \.self) { index in
                            let value = dayBars[index]
                            let isCurrent = span == .week ? (index == todayIndex) : (index == currentWeekIndexForMonth)
                            let isFuture = span == .week ? (index > todayIndex) : (index > currentWeekIndexForMonth)
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isCurrent ? Theme.accent : (isFuture ? Theme.surfaceStrong.opacity(0.4) : Theme.surfaceStrong))
                                .frame(height: value == 0 ? 4 : max(10, CGFloat(NSDecimalNumber(decimal: value / maxBar).doubleValue) * 96))
                                .overlay(
                                    isFuture && value == 0 ?
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                            .frame(height: 4)
                                    : nil
                                )
                                .scaleEffect(y: barsGrown ? 1 : 0.02, anchor: .bottom)
                                .animation(
                                    Motion.gentleSlow.delay(0.08 * Double(index)),
                                    value: barsGrown
                                )
                        }
                    }
                    .frame(height: 100)
                    .padding(.horizontal, 28)
                    .padding(.top, 26)

                    HStack(spacing: 8) {
                        ForEach(0..<barLabels.count, id: \.self) { index in
                            let isCurrent = span == .week ? (index == todayIndex) : (index == currentWeekIndexForMonth)
                            let isFuture = span == .week ? (index > todayIndex) : (index > currentWeekIndexForMonth)
                            Text(barLabels[index])
                                .font(.caption)
                                .foregroundStyle(isCurrent ? Theme.accent : (isFuture ? Theme.textTertiary.opacity(0.4) : Theme.textTertiary))
                                .fontWeight(isCurrent ? .semibold : .regular)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 6)
                }

                // Consistency: the streak wreath, streak count, freezes.
                consistencyCard
                    .padding(.horizontal, 28)
                    .padding(.top, 24)

                // Budgets — only rendered when at least one category has a
                // target + period configured. Closest-to-limit sorts first.
                if !budgetReports.isEmpty {
                    budgetsSection
                        .padding(.horizontal, 28)
                        .padding(.top, 28)
                }

                // Impulse vs. planned — a different axis from budgets, which measure
                // spend against a target. Kept as its own section for that reason.
                impulseSection(this: thisIntent, previous: lastIntent)
                    .padding(.horizontal, 28)
                    .padding(.top, 28)

                if !thisTotals.isEmpty {
                    // By category
                    VStack(alignment: .leading, spacing: 0) {
                        Text("BY CATEGORY")
                            .font(.caption2.weight(.semibold))
                            .kerning(0.9)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.bottom, 4)

                        ForEach(thisTotals.sorted { $0.value > $1.value }, id: \.key) { item in
                            let pct = thisTotal > 0
                                ? item.value / thisTotal
                                : 0
                            HStack(spacing: 12) {
                                Text(lookup.emoji(for: item.key))
                                    .font(.body)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lookup.name(for: item.key))
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Theme.textPrimary)
                                    // The impulse read rides on the existing ranking
                                    // rather than repeating it in a second list. Only
                                    // categories with marked spend say anything.
                                    if let caption = categoryIntentCaption(categoryIntents[item.key]) {
                                        Text(caption)
                                            .font(.caption2)
                                            .foregroundStyle(Theme.textTertiary)
                                    }
                                }
                                Spacer()
                                Text("\(Money.percent(pct))")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.textTertiary)
                                    .monospacedDigit()
                                Text(Money.format(item.value))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 10)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(Theme.hairline)
                                    .frame(height: 1)
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 28)
                }

                ShareLink(
                    item: CSVFile(text: CSVExporter.makeCSV(entries: exportEntries, lookup: lookup)),
                    preview: SharePreview("TapLog Export")
                ) {
                    Text("Export CSV")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.surface, in: Capsule())
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
    }

    private var recapTeaseBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("You've logged \(logsLogged) expenses so far")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Come back weekly — patterns show up fast.")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            Button {
                recapTeaseDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.accentSoft)
        .entrance()
    }

    // MARK: - Helpers

    /// The streak wreath plus streak and freeze status — the retention loop's
    /// payoff surface, so progress is visible and a freeze can be spent.
    // MARK: - Budgets

    /// One report per fully-configured budget (target > 0 and a period set) —
    /// half-configured categories are skipped by the calculator itself.
    private var budgetReports: [BudgetCalculator.Report] {
        categories
            .compactMap { BudgetCalculator.report(for: $0, entries: entries) }
            .sorted {
                ($0.utilization ?? 0) > ($1.utilization ?? 0)
            }
    }

    /// The one section that does *not* follow the span toggle. A budget resets on
    /// its own weekly or monthly cycle, and re-slicing a monthly target into a
    /// week would mean inventing a prorated figure the user never set — so the
    /// rows keep their real period and say so instead, both here and on every
    /// row's numbers.
    private var budgetsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BUDGETS")
                .font(.caption2.weight(.semibold))
                .kerning(0.9)
                .foregroundStyle(Theme.textTertiary)

            Text("Each runs on its own cycle, not the one selected above.")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
                .padding(.bottom, 4)

            ForEach(budgetReports, id: \.categoryKey) { report in
                budgetRow(report)
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Theme.hairline)
                            .frame(height: 1)
                    }
            }
        }
    }

    private func budgetRow(_ report: BudgetCalculator.Report) -> some View {
        let over = report.isOver
        let fraction = min(1, max(0, NSDecimalNumber(decimal: report.utilization ?? 0).doubleValue))
        let cadence = report.period == .monthly ? "month" : "week"
        return HStack(spacing: 12) {
            Text(lookup.emoji(for: report.categoryKey))
                .font(.body)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(lookup.name(for: report.categoryKey))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    // The cadence rides along with the numbers: a bare
                    // "₹75.00 / ₹200.00" under a "Week" heading reads as the
                    // week's, even when it's a monthly target.
                    Text("\(Money.format(report.currentSpent)) / \(Money.format(report.target)) a \(cadence)")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                BudgetProgressBar(fraction: fraction, over: over)
                Text(over
                     ? "\(Money.format(-report.remaining)) over this \(cadence)"
                     : "\(Money.format(report.remaining)) left this \(cadence)")
                    .font(.caption)
                    .foregroundStyle(over ? Theme.clay : Theme.textSecondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(lookup.name(for: report.categoryKey)): \(Money.format(report.currentSpent)) of \(Money.format(report.target)) per \(cadence). " +
            (over ? "\(Money.format(-report.remaining)) over." : "\(Money.format(report.remaining)) left.")
        )
    }

    // MARK: - Impulse vs. planned

    /// Noun for the selected span, used in copy ("this week" / "this month").
    private var spanNoun: String { span == .week ? "week" : "month" }
    private var compareNoun: String { span == .week ? "last week" : "last month" }

    /// The period's impulse read — or an invitation when there is nothing to read.
    ///
    /// Nothing here is a verdict. Impulse spending is a fact about a purchase, not
    /// a failing, so the section uses the same sage the rest of the app uses and
    /// never reaches for clay or a warning glyph the way an over-budget row does.
    @ViewBuilder
    private func impulseSection(
        this breakdown: RecapMath.IntentBreakdown,
        previous: RecapMath.IntentBreakdown
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("IMPULSE")
                .font(.caption2.weight(.semibold))
                .kerning(0.9)
                .foregroundStyle(Theme.textTertiary)

            if let share = breakdown.impulseShare {
                Text("\(Money.percent(share)) of marked spend")
                    .font(Theme.amount(26))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                    .padding(.top, 6)

                Text(impulseComparison(this: breakdown, previous: previous))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
                    .padding(.top, 2)

                IntentSplitBar(
                    impulse: breakdown.impulse,
                    planned: breakdown.planned
                )
                .padding(.top, 14)

                HStack(spacing: 16) {
                    intentLegend(
                        symbol: "bolt.fill",
                        title: "Impulse",
                        amount: breakdown.impulse,
                        filled: true
                    )
                    intentLegend(
                        symbol: "calendar",
                        title: "Planned",
                        amount: breakdown.planned,
                        filled: false
                    )
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)

                // Coverage, always — a share of marked spend means nothing without
                // knowing how much of the period is marked at all.
                Text(coverageLine(breakdown))
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                if let coverage = breakdown.coverage, coverage < Self.partialCoverageThreshold {
                    Text("The rest of this \(spanNoun) isn't marked, so read this as a partial view.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            } else {
                // No fake 0%: with nothing marked there is no share to report, so
                // the section explains how to start one instead.
                Text("Nothing marked this \(spanNoun) yet.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 6)
                Text("Tap “Impulse?” beside the category as you log. Once a few entries carry an answer, this shows how much of your spending was on purpose.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(impulseAccessibilityLabel(this: breakdown, previous: previous))
    }

    /// Below this, the section says out loud that it is reading a sample.
    private static let partialCoverageThreshold: Decimal = 0.6

    private func intentLegend(
        symbol: String,
        title: String,
        amount: Decimal,
        filled: Bool
    ) -> some View {
        HStack(spacing: 5) {
            // The swatch repeats the bar's fill so the two can be matched up
            // without relying on colour memory; the glyph and word carry the
            // meaning on their own for anyone who cannot use the colour at all.
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(filled ? Theme.accent : Theme.surfaceStrong)
                .frame(width: 8, height: 8)
            Image(systemName: symbol)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Text(Money.format(amount))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(Money.format(amount))")
    }

    /// Period-over-period line, in percentage points.
    private func impulseComparison(
        this breakdown: RecapMath.IntentBreakdown,
        previous: RecapMath.IntentBreakdown
    ) -> String {
        guard let delta = RecapMath.impulseShareDelta(current: breakdown, previous: previous) else {
            return "Nothing marked \(compareNoun) to compare with"
        }
        if delta == 0 {
            return "Level with \(compareNoun)"
        }
        // Same convention as the total above: the arrow carries the direction, so
        // the number stays unsigned.
        return "\(delta > 0 ? "▲" : "▼") \(Money.points(abs(delta))) vs. \(compareNoun)"
    }

    private func coverageLine(_ breakdown: RecapMath.IntentBreakdown) -> String {
        let entries = "\(breakdown.markedCount) of \(breakdown.entryCount) "
            + (breakdown.entryCount == 1 ? "entry" : "entries")
        guard let coverage = breakdown.coverage else { return "From \(entries)." }
        return "From \(entries) — \(Money.percent(coverage)) of this \(spanNoun)'s spend."
    }

    private func impulseAccessibilityLabel(
        this breakdown: RecapMath.IntentBreakdown,
        previous: RecapMath.IntentBreakdown
    ) -> String {
        guard let share = breakdown.impulseShare else {
            return "Impulse. Nothing marked this \(spanNoun) yet. Tap Impulse beside the category as you log."
        }
        return "Impulse. \(Money.percent(share)) of marked spend. "
            + "\(impulseComparison(this: breakdown, previous: previous)). "
            + coverageLine(breakdown)
    }

    /// Per-category caption for the BY CATEGORY list — nil when the category has
    /// no marked spend, so unmarked categories stay exactly as they were.
    private func categoryIntentCaption(_ breakdown: RecapMath.IntentBreakdown?) -> String? {
        guard let breakdown, let share = breakdown.impulseShare else { return nil }
        let headline: String
        if share == 1 {
            headline = "all impulse"
        } else if share == 0 {
            headline = "all planned"
        } else {
            headline = "\(Money.percent(share)) impulse"
        }
        // A category whose marks cover only part of its entries has to say so, or
        // "all impulse" would speak for entries the user never answered for.
        guard breakdown.markedCount < breakdown.entryCount else { return headline }
        return "\(headline) · \(breakdown.markedCount) of \(breakdown.entryCount) marked"
    }

    private var consistencyCard: some View {
        HStack(alignment: .top, spacing: 14) {
            WeeklyStreakWreath(
                daysLogged: retention.daysLoggedThisWeek,
                target: retention.weeklyTarget,
                freezesAvailable: retention.streakFreezes
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(retention.streakDescription ?? (retention.currentStreak == 0 ? "Start your streak" : "No streak yet"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(consistencyFootnote)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                if !retention.targetMet && retention.streakFreezes > 0 {
                    Button {
                        _ = retention.useStreakFreeze()
                    } label: {
                        Label("Use a freeze", systemImage: "snowflake")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// What the recap shows when the selected span holds nothing.
    ///
    /// The hero, the bars and the category split are all derived from entries,
    /// so an empty week rendered them as ₹0.00 over a row of stubs under a
    /// heading with nothing beneath it — three separate ways of saying the same
    /// nothing. One seedling says it once. The consistency card and Export stay
    /// put: the streak is about *logging*, which is exactly what an empty week
    /// needs to talk about, and Export covers all time rather than this span.
    private var emptySpanState: some View {
        SeedlingEmptyState(
            title: span == .week ? "Nothing logged this week" : "Nothing logged this month",
            message: span == .week
                ? "Log one expense and your total, the day bars and your category split all fill in here."
                : "Log one expense and your total, the week bars and your category split all fill in here."
        )
        .padding(.top, 44)
        .padding(.bottom, 8)
    }

    private var consistencyFootnote: String {
        guard !retention.targetMet else { return "Target met — nice week." }
        if retention.currentStreak == 0 && retention.daysLoggedThisWeek == 0 {
            return "Log once today to start building momentum."
        }
        let remaining = retention.weeklyTarget - retention.daysLoggedThisWeek
        if retention.currentStreak == 0 {
            return "\(remaining) more day\(remaining == 1 ? "" : "s") to start a streak."
        }
        return "\(remaining) more day\(remaining == 1 ? "" : "s") to hit your \(retention.weeklyTarget)-day target."
    }

    private var todayIndex: Int {
        RecapMath.todayIndex()
    }

    /// Index of the current week within the current month (0-based).
    ///
    /// This must use the *same* bucketing as `monthlyWeekTotals`, which splits
    /// the month into fixed seven-day blocks from the 1st. Deriving it from
    /// `weekOfMonth` instead made the two disagree whenever a month starts
    /// mid-week: the calendar counts the partial first week as W1 and rolls to
    /// W2 on the next Sunday, while the bars roll over on the 8th — so the
    /// highlighted bar could be the one next to the bar actually holding today.
    private var currentWeekIndexForMonth: Int {
        let calendar = Calendar.current
        let now = Date.now
        let monthStart = calendar.dateInterval(of: .month, for: now)!.start
        return RecapMath.monthWeekIndex(for: now, monthStart: monthStart, calendar: calendar)
    }

    /// Compute week-based recap data: (thisWeek, lastWeek, barTotals, barLabels)
    private func computeWeekData() -> ([Entry], [Entry], [Decimal], [String]) {
        let (thisWeek, lastWeek) = splitWeeks()
        let dayTotals = dailyTotals(thisWeek)
        let dayLabels = RecapMath.weekdayLabels()
        return (thisWeek, lastWeek, dayTotals, dayLabels)
    }

    /// Compute month-based recap data: (thisMonth, lastMonth, weekTotals, weekLabels)
    /// The month is split into weeks (W1-W5) with only rendered bars for weeks that exist.
    private func computeMonthData() -> ([Entry], [Entry], [Decimal], [String]) {
        let calendar = Calendar.current
        let now = Date.now

        // Current month. The `<= now` cut-off matches the one `splitWeeks`
        // applies to the weekly span: a future-dated entry sits inside this
        // month's bounds but hasn't been spent, and without the cut-off it
        // inflated the headline total, every category percentage, the impulse
        // breakdown and the bar it landed in — while the same entry was
        // correctly excluded from the weekly view of the same data.
        let thisMonthInterval = calendar.dateInterval(of: .month, for: now)!
        let thisMonth = entries.filter {
            $0.date >= thisMonthInterval.start && $0.date < thisMonthInterval.end && $0.date <= now
        }

        // Previous month
        let prevMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthInterval.start)!
        let prevMonthInterval = calendar.dateInterval(of: .month, for: prevMonthStart)!
        let lastMonth = entries.filter {
            $0.date >= prevMonthInterval.start && $0.date < prevMonthInterval.end
        }

        // Split current month into weeks
        let weekTotals = monthlyWeekTotals(thisMonth, monthStart: thisMonthInterval.start, calendar: calendar)
        let weekLabels = (1...weekTotals.count).map { "W\($0)" }

        return (thisMonth, lastMonth, weekTotals, weekLabels)
    }

    /// Splits a month's entries into weeks and returns totals for each week.
    /// Returns only as many arrays as the month actually has weeks.
    private func monthlyWeekTotals(_ month: [Entry], monthStart: Date, calendar: Calendar) -> [Decimal] {
        let monthInterval = calendar.dateInterval(of: .month, for: monthStart)!
        let totalDays = calendar.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day ?? 28
        let weeksInMonth = Int(ceil(Double(totalDays) / 7))

        var result: [Decimal] = Array(repeating: Decimal(0), count: weeksInMonth)

        for entry in month {
            let weekIndex = RecapMath.monthWeekIndex(
                for: entry.date, monthStart: monthStart, calendar: calendar
            )
            if weekIndex >= 0 && weekIndex < weeksInMonth {
                result[weekIndex] += entry.amount
            }
        }

        return result
    }

    private func dayLetter(_ index: Int) -> String {
        RecapMath.weekdayLabels()[index]
    }

    private func dailyTotals(_ week: [Entry]) -> [Decimal] {
        RecapMath.dailyTotals(week)
    }

    private func splitWeeks() -> (this: [Entry], last: [Entry]) {
        let split = RecapMath.splitWeeks(entries)
        return (split.thisWeek, split.lastWeek)
    }

    private func totals(byCategory entries: [Entry]) -> [String: Decimal] {
        RecapMath.totals(byCategory: entries)
    }
}

extension Money {
    /// Percentage string like "12.4%" from a Decimal fraction ratio.
    static func percent(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0%"
    }

    /// A difference between two percentages, in percentage *points* — "8 pts" from
    /// a 0.08 share delta. Points rather than a percent-of-a-percent: 40% → 50% is
    /// ten points, and calling it "25% more" would overstate what changed.
    static func points(_ value: Decimal) -> String {
        var scaled = value * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        let number = NSDecimalNumber(decimal: rounded).intValue
        return "\(number) pt\(number == 1 ? "" : "s")"
    }
}

/// The period's marked spend split into impulse and planned.
///
/// Two segments of one bar rather than two bars: the point is the proportion
/// between them, and the shared width makes that the thing the eye reads first.
/// Colour is never the only carrier — the legend beneath repeats each side with
/// its own glyph, word, and amount.
struct IntentSplitBar: View {
    let impulse: Decimal
    let planned: Decimal

    private var impulseFraction: CGFloat {
        let total = impulse + planned
        guard total > 0 else { return 0 }
        return CGFloat(NSDecimalNumber(decimal: impulse / total).doubleValue)
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                // A hairline minimum keeps a 0%/100% split legible as a split
                // rather than reading as a single solid bar.
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: max(impulseFraction > 0 ? 4 : 0, geometry.size.width * impulseFraction))
                Capsule()
                    .fill(Theme.surfaceStrong)
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

/// Thin horizontal budget bar — sage while under budget, clay once overspent.
/// A tiny sliver stays visible even at zero so an untouched budget still reads
/// as a bar, matching the day-chart baseline treatment.
struct BudgetProgressBar: View {
    let fraction: CGFloat
    let over: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.surfaceStrong)
                Capsule()
                    .fill(over ? Theme.clay : Theme.accent)
                    .frame(width: max(4, geometry.size.width * fraction))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}
