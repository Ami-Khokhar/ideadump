import SwiftUI
import SwiftData

/// One-tap expense tiles — the fastest way to log a recurring spend.
///
/// Shows the top 4 categories by `logCount` as tappable tiles. Each tile shows
/// the category emoji, name, and how many times it's been logged. Tapping a tile
/// pre-selects the category and amount, ready for a quick log.
///
/// The `+` tile opens the full amount pad for one-offs.
struct TileGrid: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpendCategory.sortOrder) private var categories: [SpendCategory]
    @Query(
        filter: #Predicate<Entry> { !$0.isArchived && !$0.isPending },
        sort: \Entry.date,
        order: .reverse
    ) private var activeEntries: [Entry]

    @Binding var selectedCategoryKey: String
    @Binding var amountText: String
    @FocusState.Binding var amountFocused: Bool
    let onAddTile: () -> Void

    /// Top 4 categories by logCount, excluding "other".
    private var topCategories: [SpendCategory] {
        categories
            .filter { $0.key != SpendCategory.fallbackKey }
            .sorted { $0.logCount > $1.logCount }
            .prefix(4)
            .map { $0 }
    }

    /// The category most commonly used at the current hour.
    private var timeHintKey: String? {
        let hour = Calendar.current.component(.hour, from: Date())
        var counts: [String: Int] = [:]
        for entry in activeEntries {
            let entryHour = Calendar.current.component(.hour, from: entry.date)
            if entryHour == hour {
                counts[entry.category, default: 0] += 1
            }
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    var body: some View {
        VStack(spacing: 12) {
            // Section label
            HStack {
                Text("Quick log")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 28)

            // 2×2 tile grid
            let gridItems = [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]
            LazyVGrid(columns: gridItems, spacing: 12) {
                ForEach(topCategories) { category in
                    tileButton(category)
                }
                addButton
            }
            .padding(.horizontal, 28)
        }
    }

    private func tileButton(_ category: SpendCategory) -> some View {
        let isTimeHint = category.key == timeHintKey
        let isSelected = selectedCategoryKey == category.key

        return Button {
            selectedCategoryKey = category.key
            amountFocused = true
        } label: {
            VStack(spacing: 6) {
                Text(category.emoji)
                    .font(.title2)
                Text(category.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textPrimary)
                if category.logCount > 0 {
                    Text("\(category.logCount)×")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                tileBackground(isSelected: isSelected, isTimeHint: isTimeHint),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isTimeHint ? Theme.accent.opacity(0.4) : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .scaleEffect(isSelected ? 1.03 : 1)
            .animation(Motion.gentleFast, value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private var addButton: some View {
        Button {
            onAddTile()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.light)
                Text("Other")
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func tileBackground(isSelected: Bool, isTimeHint: Bool) -> Color {
        if isSelected { return Theme.accentSoft }
        if isTimeHint { return Theme.accent.opacity(0.08) }
        return Theme.surface
    }
}
