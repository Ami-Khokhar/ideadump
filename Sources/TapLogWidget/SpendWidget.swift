import WidgetKit
import SwiftUI
import SwiftData

struct QuickButton: Identifiable {
    let amount: Double
    let categoryKey: String
    let emoji: String
    let label: String

    var id: String { "\(categoryKey)-\(amount)" }
}

/// Shown before any history exists, and whenever the store cannot be read.
/// Deliberately not main-actor isolated: `placeholder(in:)` is nonisolated.
private var defaultQuickButtons: [QuickButton] {
    [
        QuickButton(amount: 10, categoryKey: "chai", emoji: "☕️", label: "☕️ \(Money.format(10))"),
        QuickButton(amount: 40, categoryKey: "transport", emoji: "🚌", label: "🚌 \(Money.format(40))"),
        QuickButton(amount: 120, categoryKey: "food", emoji: "🍽️", label: "🍽️ \(Money.format(120))"),
    ]
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
    // `makeContainer()` traps when no candidate store opens. A trap here kills the
    // widget process and leaves the user staring at "Unable to Load", so the
    // timeline degrades to an empty snapshot instead — the same choice the share
    // extension makes.
    guard let container = try? StoreLocator.container() else {
        return SpendSnapshot(date: .now, total: 0, count: 0, quickButtons: defaultQuickButtons)
    }
    let context = container.mainContext
    let now = Date.now
    let startOfDay = Calendar.current.startOfDay(for: now)
    // Upper bound as well as lower: an entry dated later today hasn't been spent
    // yet, and without it the widget reported a total the app's own screens —
    // which all apply this cut-off — refused to show.
    let descriptor = FetchDescriptor<Entry>(
        predicate: #Predicate<Entry> {
            $0.date >= startOfDay && $0.date <= now && !$0.isArchived && !$0.isPending
        }
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

/// Learns the user's top category+amount pairs from actual history.
/// Groups all entries by (category, rounded amount), counts frequency,
/// and returns the top 3 as one-tap buttons.
@MainActor
private func makeQuickButtons(context: ModelContext) -> [QuickButton] {
    // Fetch all non-archived entries (last 90 days is enough to learn patterns)
    let now = Date.now
    let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now
    // Bounded at both ends: a future-dated entry is not history, and letting it
    // rank the buttons would put a purchase that hasn't happened on the widget.
    let descriptor = FetchDescriptor<Entry>(
        predicate: #Predicate<Entry> {
            $0.date >= ninetyDaysAgo && $0.date <= now && !$0.isArchived && !$0.isPending
        }
    )
    let entries: [Entry] = (try? context.fetch(descriptor)) ?? []

    // Fetch categories for emoji/name lookup
    let categories: [SpendCategory] = (try? context.fetch(FetchDescriptor<SpendCategory>())) ?? []
    let lookup = Dictionary(uniqueKeysWithValues: categories.map { ($0.key, $0) })

    // Group by (category, rounded amount) and count
    var counts: [QuickButtonRanking.Pattern: Int] = [:]
    for entry in entries {
        // Round to nearest common amount bucket
        let rounded = roundAmount(entry.amount)
        let key = QuickButtonRanking.Pattern(categoryKey: entry.category, amount: rounded)
        counts[key, default: 0] += 1
    }

    let top = QuickButtonRanking.top(counts)
        .map { pattern in
            let cat = lookup[pattern.categoryKey]
            let emoji = cat?.emoji ?? "🏷️"
            let amountDouble = NSDecimalNumber(decimal: pattern.amount).doubleValue
            return QuickButton(
                amount: amountDouble,
                categoryKey: pattern.categoryKey,
                emoji: emoji,
                label: "\(emoji) \(Money.format(pattern.amount))"
            )
        }

    // If no history, show sensible defaults
    if top.isEmpty {
        return defaultQuickButtons
    }

    return top
}

/// Round amounts to common buckets to group similar purchases.
/// ₹10.00 and ₹10.50 both become ₹10 — the user probably means the same thing.
private func roundAmount(_ amount: Decimal) -> Decimal {
    let double = NSDecimalNumber(decimal: amount).doubleValue
    if double < 1 { return amount } // Keep exact for sub-1 amounts
    if double < 10 { return Decimal(round(double)) } // Round to nearest 1
    if double < 50 { return Decimal(round(double / 5) * 5) } // Round to nearest 5
    if double < 200 { return Decimal(round(double / 10) * 10) } // Round to nearest 10
    return Decimal(round(double / 50) * 50) // Round to nearest 50
}

struct SpendProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpendSnapshot {
        SpendSnapshot(
            date: .now,
            total: 0,
            count: 0,
            quickButtons: defaultQuickButtons
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
        switch family {
        case .systemMedium:
            mediumView
        case .accessoryCircular:
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .widgetURL(URL(string: "taplog://log")!)
            .accessibilityLabel("Log expense")
        case .accessoryRectangular:
            Link(destination: URL(string: "taplog://log")!) {
                Label("Log expense", systemImage: "plus.circle.fill")
                    .font(.caption.weight(.semibold))
            }
            .accessibilityLabel("Open TapLog expense capture")
        default:
            smallView
        }
    }

    // MARK: - Small Widget

    private var smallView: some View {
        ZStack(alignment: .bottomTrailing) {
            // Decorative watermark — sits behind the copy at low opacity so the
            // spend total stays the thing the eye lands on first.
            TreeStateGlyph(state: .growing, color: Theme.moss)
                .widgetAccentable()
                .frame(width: 42, height: 52)
                .opacity(0.16)
                .padding(.trailing, -4)
                .padding(.bottom, -4)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Today", systemImage: "creditcard")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Text(Money.format(entry.total))
                    .font(.title2.bold())
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Link(destination: URL(string: "taplog://log")!) {
                    Text("Log expense →")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    // MARK: - Medium Widget

    private var mediumView: some View {
        ZStack(alignment: .topTrailing) {
            // Same decorative watermark as the small size, tucked into the
            // corner clear of the quick-log buttons below.
            TreeStateGlyph(state: .growing, color: Theme.moss)
                .widgetAccentable()
                .frame(width: 36, height: 44)
                .opacity(0.16)
                .padding(.top, -4)
                .padding(.trailing, 2)
                .accessibilityHidden(true)

            mediumContent
        }
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    private var mediumContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label("Today", systemImage: "creditcard")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.count) logged")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(Money.format(entry.total))
                .font(.title2.bold())
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                ForEach(entry.quickButtons) { button in
                    quickLogButton(
                        amount: button.amount,
                        category: button.categoryKey,
                        label: button.label
                    )
                }
                // Custom amount button — opens the app
                Link(destination: URL(string: "taplog://log")!) {
                    VStack(spacing: 2) {
                        Image(systemName: "number")
                            .font(.caption)
                        // The user's currency, not a hardcoded rupee — this
                        // button read "₹?" for someone logging in dollars.
                        Text("\(Money.currencySymbol)?")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.tint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func quickLogButton(amount: Double, category: String, label: String) -> some View {
        Button(intent: QuickLogIntent(amount: amount, category: category)) {
            Text(label)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
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
        .configurationDisplayName("TapLog")
        .description("Quick-log expenses from your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}
