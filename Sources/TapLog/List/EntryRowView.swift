import SwiftUI

struct EntryRowView: View {
    let entry: Entry
    let lookup: CategoryLookup

    /// Built-in categories (the thirteen `BotanicalStamp` cases) get the unified
    /// hand-inked mark. A category whose key isn't one of those — a user's own
    /// custom category, or one they picked a specific emoji for — keeps that
    /// emoji instead of collapsing to the shared `.other` fallback stamp, which
    /// would erase the choice the user actually made. `stamp(for:)` still owns
    /// the fallback for anything that needs a mark elsewhere (chips, etc.); this
    /// row only reaches for a stamp when the category truly is one of the set.
    private var builtInStamp: BotanicalStamp? {
        BotanicalStamp(rawValue: entry.category)
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let stamp = builtInStamp {
                    BotanicalStampView(stamp: stamp, color: Theme.fern)
                        .frame(width: 22, height: 22)
                } else {
                    Text(lookup.emoji(for: entry.category))
                        .font(.title3)
                }
            }
            .frame(width: 36, height: 36)
            .background(Theme.surface, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(lookup.name(for: entry.category))
                    .font(.body.weight(.medium))
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 5) {
                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    // Only marked entries say anything. An unmarked row stays
                    // exactly as it was — there is no "unmarked" badge, because
                    // the absence of an answer is not a fact about the purchase.
                    if let intent = entry.intent {
                        Text("·")
                        // An explicit HStack rather than a Label: Label reserves a
                        // fixed icon column that leaves a visible gap at caption2,
                        // which made a deliberately quiet indicator draw the eye.
                        HStack(spacing: 3) {
                            Image(systemName: intent == .impulse ? "bolt.fill" : "calendar")
                                .imageScale(.small)
                            Text(intent == .impulse ? "Impulse" : "Planned")
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            intent == .impulse ? "Marked impulse" : "Marked planned"
                        )
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            Spacer()
            Text(Money.format(entry.amount))
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 2)
        .opacity(entry.isArchived ? 0.6 : 1)
    }
}
