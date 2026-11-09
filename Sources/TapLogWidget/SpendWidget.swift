import WidgetKit
import SwiftUI
import SwiftData

/// Shown before any history exists, and whenever the store cannot be read.
/// Deliberately not main-actor isolated: `placeholder(in:)` is nonisolated.
private var defaultQuickButtons: [QuickButton] {
    [
        QuickButton(amount: 10, categoryKey: "chai", emoji: "☕️", label: "☕️ \(Money.format(10))"),
        QuickButton(amount: 40, categoryKey: "transport", emoji: "🚌", label: "🚌 \(Money.format(40))"),
        QuickButton(amount: 120, categoryKey: "food", emoji: "🍽️", label: "🍽️ \(Money.format(120))"),
    ]
}

/// Fetches today's totals from the shared store. Lives outside the provider struct
/// because WidgetKit's `TimelineProvider` declares an associated type named `Entry`,
/// which shadows the SwiftData model of the same name.
@MainActor
private func loadTodaySnapshot() -> SpendSnapshot {
    let context: ModelContext
    do {
        context = try StoreLocator.widgetReadContext()
    } catch StoreLocator.StoreError.widgetRequiresSharedStore {
        // The store opened, but at the app-only fallback location the widget
        // cannot read. Naming an open failure here would send support looking
        // for an error that never happened.
        Log.store.warning("widget snapshot unavailable: store in use is not the shared App Group store")
        return unavailableSnapshot()
    } catch {
        Log.store.error("widget snapshot unavailable: shared store could not be opened (\(Log.describe(error), privacy: .public))")
        return unavailableSnapshot()
    }

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
    let totals = WidgetSnapshotTotals.map { try context.fetch(descriptor) }
    guard totals.isAvailable else { return unavailableSnapshot() }

    let quickButtons: [QuickButton]
    do {
        quickButtons = try makeQuickButtons(context: context)
    } catch {
        // One consistent state: a history read that failed must not render the
        // hard-coded default tiles as if they were learned from the user.
        Log.store.error("widget snapshot unavailable: quick-button history read failed (\(Log.describe(error), privacy: .public))")
        return unavailableSnapshot()
    }

    Log.store.notice("widget snapshot read shared store with \(totals.count, privacy: .public) entries")
    return SpendSnapshot(
        date: .now,
        total: totals.total,
        count: totals.count,
        quickButtons: quickButtons,
        isAvailable: true
    )
}

private func unavailableSnapshot() -> SpendSnapshot {
    SpendSnapshot(date: .now, total: 0, count: 0, quickButtons: defaultQuickButtons, isAvailable: false)
}

/// Learns the user's top category+amount pairs from actual history.
/// Groups all entries by (category, rounded amount), counts frequency,
/// and returns the top 3 as one-tap buttons.
/// Throws rather than swallowing: a failed read must not look like history.
@MainActor
private func makeQuickButtons(context: ModelContext) throws -> [QuickButton] {
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
    let entries = try context.fetch(descriptor)

    // Fetch categories for emoji/name lookup
    let categories = try context.fetch(FetchDescriptor<SpendCategory>())
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
            quickButtons: defaultQuickButtons,
            isAvailable: true
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
            let timeline = SpendTimeline.entries(
                now: .now,
                snapshot: snapshot,
                calendar: .current
            )

            // WidgetKit treats `.after` and app-triggered reloads as requests; its
            // per-widget budget can defer or drop them. Log saves, currency changes,
            // and foregrounding request immediate reloads, but no cadence is exact.
            // A log rebuilds this timeline (including the pending midnight entry).
            // If WidgetKit defers that reload, the old zero reset can briefly hide
            // same-day logs after midnight; widgets cannot fetch a new total at the
            // boundary without a granted timeline refresh.
            completion(Timeline(
                entries: timeline.entries,
                policy: .after(timeline.refreshAfter)
            ))
        }
    }
}

struct SpendWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: SpendSnapshot

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .accessoryCircular:
            // The URL and label belong on the Image itself: an accessibility
            // label on a plain container is only applied when that container is
            // made an element, so a wrapping ZStack lost it and VoiceOver read
            // the bare SF Symbol.
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .widgetURL(AccessoryWidgetRoute.circular.url)
                .accessibilityLabel(AccessoryWidgetRoute.circular.label)
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        case .accessoryRectangular:
            // One element for the icon and text, so VoiceOver reads the label
            // instead of announcing "Add" and "Log expense" separately.
            HStack(spacing: 5) {
                Image(systemName: "plus.circle.fill")
                Text(AccessoryWidgetRoute.rectangular.label)
            }
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .widgetURL(AccessoryWidgetRoute.rectangular.url)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AccessoryWidgetRoute.rectangular.label)
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        default:
            EmptyView()
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
                    Label(
                        entry.isAvailable ? "Today" : "Unavailable",
                        systemImage: entry.isAvailable ? "creditcard" : "exclamationmark.triangle"
                    )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                if entry.isAvailable {
                    Text(Money.format(entry.total))
                        .font(.title2.bold())
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                } else {
                    Text("Data unavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                captureButton(.smallFooter) {
                    Text(entry.isAvailable ? "Log expense →" : "Open TapLog →")
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
                Label(
                    entry.isAvailable ? "Today" : "Unavailable",
                    systemImage: entry.isAvailable ? "creditcard" : "exclamationmark.triangle"
                )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if entry.isAvailable {
                    Text("\(entry.count) logged")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if entry.isAvailable {
                Text(Money.format(entry.total))
                    .font(.title2.bold())
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            } else {
                Text("Widget data unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                if entry.isAvailable {
                    ForEach(entry.quickButtons) { button in
                        quickLogButton(
                            amount: button.amount,
                            category: button.categoryKey,
                            label: button.label
                        )
                    }
                    // Custom amount button — opens the app
                    captureButton(.mediumCustomAmount) {
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
                } else {
                    captureButton(.mediumUnavailable) {
                        Label("Open TapLog", systemImage: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// A home-screen capture tap. It runs `OpenCaptureIntent` in the widget's own
    /// process instead of opening `taplog://log`, so the durable pending flag is
    /// already written when the app reads it for the first render and the opening
    /// plant never mounts — a URL would arrive at `onOpenURL` after that render
    /// and flash part of the animation first. `WidgetCaptureTap` names every site
    /// and the test pins them, so one cannot slide back to a URL unnoticed.
    private func captureButton(
        _ tap: WidgetCaptureTap,
        @ViewBuilder label: () -> some View
    ) -> some View {
        Button(intent: OpenCaptureIntent()) {
            label()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(tap.rawValue)
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
    let kind = WidgetReload.kind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpendProvider()) { entry in
            SpendWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("TapLog")
        .description("Quick-log expenses from your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}
