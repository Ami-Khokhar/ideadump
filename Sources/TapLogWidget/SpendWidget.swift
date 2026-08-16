import WidgetKit
import SwiftUI
import SwiftData

struct SpendSnapshot: TimelineEntry {
    let date: Date
    let total: Decimal
    let count: Int
}

/// Fetches today's totals from the shared store. Lives outside the provider struct
/// because WidgetKit's `TimelineProvider` declares an associated type named `Entry`,
/// which shadows the SwiftData model of the same name.
@MainActor
private func loadTodaySnapshot() -> SpendSnapshot {
    let container = StoreLocator.makeContainer()
    let context = container.mainContext
    let startOfDay = Calendar.current.startOfDay(for: .now)
    let descriptor = FetchDescriptor<Entry>(
        predicate: #Predicate<Entry> { $0.date >= startOfDay && !$0.isArchived && !$0.isPending }
    )
    let entries: [Entry] = (try? context.fetch(descriptor)) ?? []
    let total = entries.reduce(Decimal(0)) { $0 + $1.amount }
    return SpendSnapshot(date: .now, total: total, count: entries.count)
}

struct SpendProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpendSnapshot {
        SpendSnapshot(date: .now, total: 0, count: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SpendSnapshot) -> Void) {
        Task { @MainActor in
            completion(loadTodaySnapshot())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpendSnapshot>) -> Void) {
        Task { @MainActor in
            let snapshot = loadTodaySnapshot()
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now)
                ?? .now.addingTimeInterval(900)
            completion(Timeline(entries: [snapshot], policy: .after(nextRefresh)))
        }
    }
}

struct SpendWidgetEntryView: View {
    var entry: SpendSnapshot

    var body: some View {
        Link(destination: URL(string: "taplog://log")!) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Today", systemImage: "creditcard")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(Money.format(entry.total))
                    .font(.title2.bold())
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("\(entry.count) \(entry.count == 1 ? "log" : "logs")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }
}

struct SpendWidget: Widget {
    let kind = "SpendWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpendProvider()) { entry in
            SpendWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today's Spend")
        .description("Your total spending today, at a glance. Tap to log.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
