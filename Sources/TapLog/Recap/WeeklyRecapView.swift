import SwiftUI
import SwiftData

struct WeeklyRecapView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isProDemo") private var isPro = false
    @AppStorage("logsLogged") private var logsLogged = 0
    @AppStorage("recapTeaseDismissed") private var recapTeaseDismissed = false

    @Query(filter: #Predicate<Entry> { !$0.isArchived && !$0.isPending }, sort: \Entry.date)
    private var entries: [Entry]

    @Query(sort: \SpendCategory.sortOrder)
    private var categories: [SpendCategory]

    private var lookup: CategoryLookup { CategoryLookup(categories) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if logsLogged >= 5 && !recapTeaseDismissed {
                    recapTeaseBanner
                }
                Group {
                    if isPro {
                        recapContent
                    } else {
                        ProLocked(feature: "Weekly Recap")
                    }
                }
            }
            .background(Theme.background)
            .navigationTitle("Recap")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
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
                    Text(Money.format(thisTotal))
                        .font(Theme.amount(46))
                        .foregroundStyle(Theme.textPrimary)
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

                // Bars
                HStack(alignment: .bottom, spacing: 8) {
                    let maxDay = max(dayTotals.max() ?? 1, 1)
                    ForEach(0..<7, id: \.self) { index in
                        let value = dayTotals[index]
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(index == todayIndex ? Theme.accent : Theme.surfaceStrong)
                            .frame(height: value == 0 ? 4 : max(10, CGFloat(NSDecimalNumber(decimal: value / maxDay).doubleValue) * 96))
                    }
                }
                .frame(height: 100)
                .padding(.horizontal, 28)
                .padding(.top, 26)

                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { index in
                        Text(dayLetter(index))
                            .font(.caption)
                            .foregroundStyle(index == todayIndex ? Theme.accent : Theme.textTertiary)
                            .fontWeight(index == todayIndex ? .semibold : .regular)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 6)

                // By category
                VStack(alignment: .leading, spacing: 0) {
                    Text("BY CATEGORY")
                        .font(.caption2.weight(.semibold))
                        .kerning(0.9)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.bottom, 4)

                    ForEach(thisTotals.sorted { $0.value > $1.value }, id: \.key) { item in
                        let pct = thisTotal > 0
                            ? (item.value / thisTotal) * 100
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
                    item: CSVFile(text: CSVExporter.makeCSV(entries: entries, lookup: lookup)),
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
    }

    // MARK: - Helpers

    private var todayIndex: Int {
        (Calendar.current.component(.weekday, from: .now) + 5) % 7 // Mon = 0
    }

    private func dayLetter(_ index: Int) -> String {
        ["M", "T", "W", "T", "F", "S", "S"][index]
    }

    private func dailyTotals(_ week: [Entry]) -> [Decimal] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)!.start
        var result = Array(repeating: Decimal(0), count: 7)
        for entry in week {
            let day = calendar.dateComponents([.day], from: start, to: entry.date).day ?? 0
            guard day >= 0 && day < 7 else { continue }
            result[day] += entry.amount
        }
        return result
    }

    private func splitWeeks() -> (this: [Entry], last: [Entry]) {
        let calendar = Calendar.current
        let thisStart = calendar.dateInterval(of: .weekOfYear, for: .now)!.start
        let lastStart = calendar.date(byAdding: .day, value: -7, to: thisStart)!
        let this = entries.filter { $0.date >= thisStart }
        let last = entries.filter { $0.date >= lastStart && $0.date < thisStart }
        return (this, last)
    }

    private func totals(byCategory entries: [Entry]) -> [String: Decimal] {
        var result: [String: Decimal] = [:]
        for entry in entries {
            result[entry.category, default: 0] += entry.amount
        }
        return result
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
