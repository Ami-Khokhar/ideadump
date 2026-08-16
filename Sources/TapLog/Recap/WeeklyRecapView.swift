import SwiftUI
import SwiftData

struct WeeklyRecapView: View {
    @AppStorage("isProDemo") private var isPro = false

    @Query(filter: #Predicate<Entry> { !$0.isArchived && !$0.isPending }, sort: \Entry.date)
    private var entries: [Entry]

    var body: some View {
        NavigationStack {
            Group {
                if isPro {
                    recapContent
                } else {
                    ProLocked(feature: "Weekly Recap")
                }
            }
            .navigationTitle("Recap")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isPro {
                        ShareLink(
                            item: CSVFile(text: CSVExporter.makeCSV(entries: entries)),
                            preview: SharePreview("TapLog Export")
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    private var recapContent: some View {
        let (thisWeek, lastWeek) = splitWeeks()
        let thisTotals = totals(byCategory: thisWeek)
        let lastTotals = totals(byCategory: lastWeek)
        let thisTotal = thisWeek.reduce(Decimal(0)) { $0 + $1.amount }
        let lastTotal = lastWeek.reduce(Decimal(0)) { $0 + $1.amount }
        let maxAmount = max(thisTotals.values.max() ?? 1, 1)

        return List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Money.format(thisTotal))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("\(Money.format(lastTotal)) last week")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("By category") {
                ForEach(thisTotals.sorted { $0.value > $1.value }, id: \.key) { item in
                    HStack {
                        Text(SpendCategory.emoji(for: item.key))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(SpendCategory.name(for: item.key))
                            ProgressView(
                                value: Double(truncating: NSDecimalNumber(decimal: item.value)),
                                total: Double(truncating: NSDecimalNumber(decimal: maxAmount))
                            )
                            .tint(.accentColor)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(Money.format(item.value))
                                .fontWeight(.semibold)
                                .monospacedDigit()
                            if let last = lastTotals[item.key] {
                                Text("\(Money.format(last)) last wk")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
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
