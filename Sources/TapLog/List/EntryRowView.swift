import SwiftUI

struct EntryRowView: View {
    let entry: Entry
    let lookup: CategoryLookup

    var body: some View {
        HStack(spacing: 12) {
            Text(lookup.emoji(for: entry.category))
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(Color(.secondarySystemBackground), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(lookup.name(for: entry.category))
                    .font(.body.weight(.medium))
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
