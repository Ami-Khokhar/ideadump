import WidgetKit
import SwiftUI
import SwiftData

struct QuickButton: Identifiable {
    let amount: Double
    let categoryKey: String
    let label: String

    var id: String { categoryKey }
}

struct SpendSnapshot: TimelineEntry {
    let date: Date
    let total: Decimal
    let count: Int
    let quickButtons: [QuickButton]
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
    return SpendSnapshot(
        date: .now,
        total: total,
        count: entries.count,
        quickButtons: makeQuickButtons(context: context)
    )
}

/// The medium widget's two tap-to-log buttons. Prefers the classic Coffee/Food
/// categories but falls back to whatever the user actually has — the labels must
/// never point at deleted categories (onboarding encourages trimming them).
@MainActor
private func makeQuickButtons(context: ModelContext) -> [QuickButton] {
    let categories = (try? context.fetch(FetchDescriptor<SpendCategory>())) ?? []
    let amounts: [Double] = [4.5, 12]

    var chosen: [SpendCategory] = []
    for preferred in ["coffee", "food"] {
        if let category = categories.first(where: { $0.key == preferred }) {
            chosen.append(category)
        }
    }
    for category in categories where !chosen.contains(where: { $0.key == category.key }) {
        if chosen.count >= 2 { break }
        chosen.append(category)
    }

    if chosen.isEmpty {
        // No categories at all — fall back to the classic defaults; the intent
        // itself resolves the key to the fallback category.
        return amounts.enumerated().map { index, amount in
            let key = ["coffee", "food"][index]
            return QuickButton(
                amount: amount,
                categoryKey: key,
                label: "\([ "☕️", "🍽️"][index]) \(Money.format(Money.fromAmount(amount)))"
            )
        }
    }

    return chosen.prefix(2).enumerated().map { index, category in
        QuickButton(
            amount: amounts[index],
            categoryKey: category.key,
            label: "\(category.emoji) \(Money.format(Money.fromAmount(amounts[index])))"
        )
    }
}

struct SpendProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpendSnapshot {
        SpendSnapshot(
            date: .now,
            total: 0,
            count: 0,
            quickButtons: [
                QuickButton(amount: 4.5, categoryKey: "coffee", label: "☕️ $4.50"),
                QuickButton(amount: 12, categoryKey: "food", label: "🍽️ $12.00"),
            ]
        )
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
                    ForEach(entry.quickButtons) { button in
                        quickLogButton(
                            amount: button.amount,
                            category: button.categoryKey,
                            label: button.label
                        )
                    }
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
