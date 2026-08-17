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
    @Environment(\.widgetFamily) private var family
    var entry: SpendSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label("Today", systemImage: "creditcard")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(Money.format(entry.total))
                .font(.title2.bold())
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Spacer(minLength: 0)
            if family == .systemMedium {
                HStack(spacing: 8) {
                    quickLogButton(amount: 4.5, category: "coffee", label: "☕️ $4.50")
                    quickLogButton(amount: 12, category: "food", label: "🍽️ $12")
                }
            } else {
                Link(destination: URL(string: "taplog://log")!) {
                    Text("Tap to log")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    private func quickLogButton(amount: Double, category: String, label: String) -> some View {
        Button(intent: QuickLogIntent(amount: amount, category: category)) {
            Text(label)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
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
