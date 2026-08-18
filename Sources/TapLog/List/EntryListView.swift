import SwiftUI
import SwiftData
import WidgetKit

/// One-shot onboarding beats. Chained via `onboardingActive`; the current step is
/// persisted so a mid-session kill resumes instead of restarting from the welcome.
enum OnboardingStep: Int, Identifiable {
    case welcome = 0
    case capture = 1
    case categories = 2
    case frontDoors = 3

    var id: Int { rawValue }
}

/// The History tab — a browse surface for past entries. Logging happens on the
/// home (Log) tab, so this screen has no "+"; entries are edited on tap and
/// archived/deleted by swipe.
struct EntryListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var undoStack: UndoStack
    @Environment(\.dismiss) private var dismiss

    @AppStorage("isProDemo") private var isPro = false

    @Query(filter: #Predicate<Entry> { !$0.isArchived && !$0.isPending }, sort: \Entry.date, order: .reverse)
    private var activeEntries: [Entry]

    @Query(filter: #Predicate<Entry> { $0.isArchived }, sort: \Entry.date, order: .reverse)
    private var archivedEntries: [Entry]

    @Query(filter: #Predicate<Entry> { $0.isPending }, sort: \Entry.date, order: .reverse)
    private var pendingEntries: [Entry]

    @Query(sort: \SpendCategory.sortOrder)
    private var categories: [SpendCategory]

    @State private var showingArchived = false
    @State private var showingSetupSheet = false
    @State private var editingEntry: Entry?

    private var displayedEntries: [Entry] {
        showingArchived ? archivedEntries : activeEntries
    }

    private var lookup: CategoryLookup { CategoryLookup(categories) }

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
                                : "Log your first expense on the Log tab — it takes about 5 seconds."
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
                                EntryRowView(entry: entry, lookup: lookup)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingEntry = entry }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        if showingArchived {
                                            Button("Unarchive") { unarchive(entry) }
                                                .tint(Theme.accent)
                                        } else {
                                            Button("Archive") { archive(entry) }
                                                .tint(Theme.accent)
                                        }
                                        Button(role: .destructive) { delete(entry) } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("History")
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    debugMenu
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingSetupSheet = true
                        } label: {
                            Label("Log without opening TapLog", systemImage: "sparkles")
                        }
                        Divider()
                        Picker("View", selection: $showingArchived) {
                            Label("Active", systemImage: "list.bullet").tag(false)
                            Label("Archived", systemImage: "archivebox").tag(true)
                        }
                    } label: {
                        Image(systemName: showingArchived ? "archivebox.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingSetupSheet) {
                SetupFrontDoorsView()
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $editingEntry) { entry in
                CaptureForm(mode: .edit(entry))
                    .environmentObject(undoStack)
            }
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
                .tint(Theme.accent)
            Button("Discard", role: .destructive) { discardPending(entry) }
                .buttonStyle(.bordered)
        }
        .contentShape(Rectangle())
        .onTapGesture { editingEntry = entry }
    }

    private func confirmPending(_ entry: Entry) {
        withAnimation(Motion.stateChange) {
            entry.isPending = false
            try? modelContext.save()
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "SpendWidget")
        undoStack.record("Added \(Money.format(entry.amount))") {
            entry.isPending = true
            try? modelContext.save()
        }
    }

    private func discardPending(_ entry: Entry) {
        let snapshot = (amount: entry.amount, category: entry.category, note: entry.note, date: entry.date)
        withAnimation(Motion.stateChange) {
            modelContext.delete(entry)
            try? modelContext.save()
        }
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
        withAnimation(Motion.stateChange) {
            entry.isArchived = true
            try? modelContext.save()
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "SpendWidget")
        undoStack.record("Archived \(Money.format(entry.amount))") {
            entry.isArchived = false
            try? modelContext.save()
        }
    }

    private func unarchive(_ entry: Entry) {
        withAnimation(Motion.stateChange) {
            entry.isArchived = false
            try? modelContext.save()
        }
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
        withAnimation(Motion.stateChange) {
            modelContext.delete(entry)
            try? modelContext.save()
        }
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
