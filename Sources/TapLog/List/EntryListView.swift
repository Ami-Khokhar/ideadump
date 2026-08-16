import SwiftUI
import SwiftData
import WidgetKit

struct EntryListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var undoStack: UndoStack

    @AppStorage("isProDemo") private var isPro = false

    @Query(filter: #Predicate<Entry> { !$0.isArchived && !$0.isPending }, sort: \Entry.date, order: .reverse)
    private var activeEntries: [Entry]

    @Query(filter: #Predicate<Entry> { $0.isArchived }, sort: \Entry.date, order: .reverse)
    private var archivedEntries: [Entry]

    @Query(filter: #Predicate<Entry> { $0.isPending }, sort: \Entry.date, order: .reverse)
    private var pendingEntries: [Entry]

    @State private var showingArchived = false
    @State private var showingCapture = false
    @State private var capturePrefill: CapturePrefill?
    @State private var editingEntry: Entry?

    private var displayedEntries: [Entry] {
        showingArchived ? archivedEntries : activeEntries
    }

    var body: some View {
        NavigationStack {
            Group {
                if displayedEntries.isEmpty && pendingEntries.isEmpty {
                    ContentUnavailableView(
                        showingArchived ? "No archived entries" : "No expenses yet",
                        systemImage: showingArchived ? "archivebox" : "plus.circle",
                        description: Text(
                            showingArchived
                                ? "Archived entries appear here."
                                : "Tap + or use the Action Button to log your first expense."
                        )
                    )
                } else {
                    List {
                        if !showingArchived && !pendingEntries.isEmpty {
                            Section("Pending from share sheet") {
                                ForEach(pendingEntries) { entry in
                                    pendingRow(entry)
                                }
                            }
                        }
                        Section(showingArchived ? "Archived" : "Recent") {
                            ForEach(displayedEntries) { entry in
                                EntryRowView(entry: entry)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingEntry = entry }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        if showingArchived {
                                            Button("Unarchive") { unarchive(entry) }
                                                .tint(.blue)
                                        } else {
                                            Button("Archive") { archive(entry) }
                                                .tint(.orange)
                                        }
                                        Button(role: .destructive) { delete(entry) } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("TapLog")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    debugMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("View", selection: $showingArchived) {
                            Label("Active", systemImage: "list.bullet").tag(false)
                            Label("Archived", systemImage: "archivebox").tag(true)
                        }
                    } label: {
                        Image(systemName: showingArchived ? "archivebox.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        capturePrefill = nil
                        showingCapture = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCapture, onDismiss: { capturePrefill = nil }) {
                CaptureForm(mode: .create, prefill: capturePrefill ?? CapturePrefill())
                    .environmentObject(undoStack)
            }
            .sheet(item: $editingEntry) { entry in
                CaptureForm(mode: .edit(entry))
                    .environmentObject(undoStack)
            }
            .onOpenURL { url in
                guard let prefill = CapturePrefill(url: url) else { return }
                capturePrefill = prefill
                showingCapture = true
            }
            .overlay(alignment: .bottom) { UndoToast() }
        }
    }

    private var debugMenu: some View {
        Menu {
            Button("Seed sample data") { DebugSeeder.seed(context: modelContext) }
            Button(isPro ? "Turn Pro off (demo)" : "Turn Pro on (demo)") { isPro.toggle() }
            Button("Delete all entries", role: .destructive) { clearAll() }
        } label: {
            Image(systemName: "hammer")
        }
    }

    // MARK: - Pending (share sheet) actions

    private func pendingRow(_ entry: Entry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.amount == 0 ? "No amount yet" : Money.format(entry.amount))
                    .font(.body.weight(.semibold))
                Text(entry.note ?? "From share sheet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("Add") { confirmPending(entry) }
                .buttonStyle(.bordered)
                .tint(.accentColor)
            Button("Discard", role: .destructive) { discardPending(entry) }
                .buttonStyle(.bordered)
        }
        .contentShape(Rectangle())
        .onTapGesture { editingEntry = entry }
    }

    private func confirmPending(_ entry: Entry) {
        entry.isPending = false
        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "SpendWidget")
        undoStack.record("Added \(Money.format(entry.amount))") {
            entry.isPending = true
            try? modelContext.save()
        }
    }

    private func discardPending(_ entry: Entry) {
        let snapshot = (amount: entry.amount, category: entry.category, note: entry.note, date: entry.date)
        modelContext.delete(entry)
        try? modelContext.save()
        undoStack.record("Discarded pending entry") {
            let restored = Entry(
                amount: snapshot.amount,
                category: snapshot.category,
                note: snapshot.note,
                date: snapshot.date,
                isPending: true
            )
            modelContext.insert(restored)
            try? modelContext.save()
        }
    }

    // MARK: - Active / archived actions

    private func archive(_ entry: Entry) {
        entry.isArchived = true
        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "SpendWidget")
        undoStack.record("Archived \(Money.format(entry.amount))") {
            entry.isArchived = false
            try? modelContext.save()
        }
    }

    private func unarchive(_ entry: Entry) {
        entry.isArchived = false
        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "SpendWidget")
        undoStack.record("Restored \(Money.format(entry.amount))") {
            entry.isArchived = true
            try? modelContext.save()
        }
    }

    private func delete(_ entry: Entry) {
        let snapshot = (
            amount: entry.amount,
            category: entry.category,
            note: entry.note,
            date: entry.date,
            archived: entry.isArchived
        )
        modelContext.delete(entry)
        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "SpendWidget")
        undoStack.record("Deleted \(Money.format(snapshot.amount))") {
            let restored = Entry(
                amount: snapshot.amount,
                category: snapshot.category,
                note: snapshot.note,
                date: snapshot.date,
                isArchived: snapshot.archived
            )
            modelContext.insert(restored)
            try? modelContext.save()
        }
    }

    // MARK: - Debug

    private func clearAll() {
        let all = try? modelContext.fetch(FetchDescriptor<Entry>())
        for entry in all ?? [] {
            modelContext.delete(entry)
        }
        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "SpendWidget")
    }
}
