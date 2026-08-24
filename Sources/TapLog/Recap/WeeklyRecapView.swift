import SwiftUI
import SwiftData

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

    private var lookup: CategoryLookup { CategoryLookup(categories) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if logsLogged >= 5 && !recapTeaseDismissed {
                    recapTeaseBanner
                }
                recapContent
            }
            .background(Theme.background)
            .navigationTitle("Recap")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                // Let the sheet settle before the bars rise.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    barsGrown = true
                }
            }
        }
    }

    // MARK: - Recap content

    private var recapContent: some View {
        let (thisWeek, lastWeek) = splitWeeks()
        let thisTotals = totals(byCategory: thisWeek)
        let thisTotal = thisWeek.reduce(Decimal(0)) { $0 + $1.amount }
        let lastTotal = lastWeek.reduce(Decimal(0)) { $0 + $1.amount }
        let dayTotals = dailyTotals(thisWeek)

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This week")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .entrance()
                    Text(Money.format(thisTotal))
                        .font(Theme.amount(46))
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                        .entrance(delay: 0.08)
                    if lastTotal > 0 && thisTotal != lastTotal {
                        let pct = (thisTotal - lastTotal) / lastTotal
                        let up = thisTotal > lastTotal
                        Text("\(up ? "▲" : "▼") \(Money.percent(pct)) vs. last week")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(up ? Theme.accent : Theme.textSecondary)
                            .monospacedDigit()
                    } else {
                        Text("\(Money.format(lastTotal)) last week")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .animation(Motion.stateChange, value: thisTotal)

                // Bars
                HStack(alignment: .bottom, spacing: 8) {
                    let maxDay = max(dayTotals.max() ?? 1, 1)
                    ForEach(0..<7, id: \.self) { index in
                        let value = dayTotals[index]
                        let isFuture = index > todayIndex
                        let isPast = index < todayIndex
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(index == todayIndex ? Theme.accent : (isFuture ? Theme.surfaceStrong.opacity(0.4) : Theme.surfaceStrong))
                            .frame(height: value == 0 ? 4 : max(10, CGFloat(NSDecimalNumber(decimal: value / maxDay).doubleValue) * 96))
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
                    ForEach(0..<7, id: \.self) { index in
                        let isFuture = index > todayIndex
                        Text(dayLetter(index))
                            .font(.caption)
                            .foregroundStyle(index == todayIndex ? Theme.accent : (isFuture ? Theme.textTertiary.opacity(0.4) : Theme.textTertiary))
                            .fontWeight(index == todayIndex ? .semibold : .regular)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 6)

                // Consistency: weekly target ring, streak, freezes.
                consistencyCard
                    .padding(.horizontal, 28)
                    .padding(.top, 24)

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
                            Text(lookup.name(for: item.key))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.textPrimary)
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

    /// Weekly-target ring plus streak and freeze status — the retention loop's
    /// payoff surface, so progress is visible and a freeze can be spent.
    private var consistencyCard: some View {
        HStack(alignment: .top, spacing: 14) {
            WeeklyRingView(
                progress: retention.ringFraction,
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

    private func dayLetter(_ index: Int) -> String {
        ["M", "T", "W", "T", "F", "S", "S"][index]
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
}
