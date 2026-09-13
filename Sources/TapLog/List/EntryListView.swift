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
    @Environment(RetentionManager.self) private var retention


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
    @State private var showingClearConfirmation = false

    private var displayedEntries: [Entry] {
        showingArchived ? archivedEntries : activeEntries
    }

    // MARK: - Date grouping

    private struct DateGroup: Identifiable {
        let id = UUID()
        let title: String
        let entries: [Entry]
    }

    private var groupedEntries: [DateGroup] {
        guard !showingArchived else { return [DateGroup(title: "Archived", entries: displayedEntries)] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)!.start

        var groups: [DateGroup] = []
        var todayEntries: [Entry] = []
        var yesterdayEntries: [Entry] = []
        var thisWeekEntries: [Entry] = []
        var earlierEntries: [Entry] = []

        for entry in displayedEntries {
            if calendar.isDate(entry.date, inSameDayAs: today) {
                todayEntries.append(entry)
            } else if calendar.isDate(entry.date, inSameDayAs: yesterday) {
                yesterdayEntries.append(entry)
            } else if entry.date >= weekStart {
                thisWeekEntries.append(entry)
            } else {
                earlierEntries.append(entry)
            }
        }

        if !todayEntries.isEmpty { groups.append(DateGroup(title: "Today", entries: todayEntries)) }
        if !yesterdayEntries.isEmpty { groups.append(DateGroup(title: "Yesterday", entries: yesterdayEntries)) }
        if !thisWeekEntries.isEmpty { groups.append(DateGroup(title: "This Week", entries: thisWeekEntries)) }
        if !earlierEntries.isEmpty { groups.append(DateGroup(title: "Earlier", entries: earlierEntries)) }

        return groups
    }

    private var lookup: CategoryLookup { CategoryLookup(categories) }

    var body: some View {
        NavigationStack {
            Group {
                if displayedEntries.isEmpty && pendingEntries.isEmpty {
                    if showingArchived {
                        // The archive keeps the plain system treatment. It is a
                        // drawer the user reached by filtering, not a garden
                        // waiting to be planted — a seedling here would promise
                        // growth for entries that have already been put away.
                        ContentUnavailableView(
                            "No archived entries",
                            systemImage: "archivebox",
                            description: Text("Archived entries appear here.")
                        )
                    } else {
                        SeedlingEmptyState(
                            title: "Nothing logged yet",
                            message: "Log your first expense on the Log tab — it takes about 5 seconds."
                        )
                        .frame(maxHeight: .infinity)
                    }
                } else {
                    List {
                        if !showingArchived && !pendingEntries.isEmpty {
                            Section {
                                ForEach(pendingEntries) { entry in
                                    pendingRow(entry)
                                }
                            } header: {
                                fieldNoteHeader("Pending from share sheet")
                            }
                        }
                        if showingArchived {
                            Section {
                                ForEach(displayedEntries) { entry in
                                    entryRow(entry)
                                }
                            } header: {
                                fieldNoteHeader("Archived")
                            }
                        } else {
                            ForEach(groupedEntries) { group in
                                Section {
                                    ForEach(group.entries) { entry in
                                        entryRow(entry)
                                    }
                                } header: {
                                    fieldNoteHeader(group.title)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .floatingToolbarScrollEdge()
                }
            }
            .navigationTitle("History")
            .background(PaperGround())
            .toolbar {
#if DEBUG
                ToolbarItem(placement: .topBarLeading) {
                    debugMenu
                }
#endif
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingSetupSheet = true
                        } label: {
                            Label("Faster ways to log", systemImage: "sparkles")
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
                SetupFrontDoorsView(onDone: {
                    OnboardingFlow.dismissFasterWays()
                })
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $editingEntry) { entry in
                CaptureForm(entry: entry)
                    .environmentObject(undoStack)
            }
            .confirmationDialog(
                "Delete all entries?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) {
                    clearAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes your history and resets your consistency progress.")
            }
        }
        // Archive, unarchive and delete all record an undo, and every one of
        // them happened inside this sheet — where the root's toast is covered by
        // the sheet itself. Without this the action was recorded and then simply
        // expired, five seconds later, behind the screen that caused it.
        .overlay(alignment: .bottom) {
            UndoToast(bottomInset: UndoToast.sheetInset)
        }
    }

#if DEBUG
    private var debugMenu: some View {
        Menu {
            Button("Seed sample data") { DebugSeeder.seed(context: modelContext) }
            Divider()
            Button("Delete all entries", role: .destructive) { showingClearConfirmation = true }
        } label: {
            Image(systemName: "hammer")
        }
    }
#endif

    /// A field-note section header: a small editorial-serif label over a
    /// hairline rule, standing in for the system's bold uppercase section
    /// title. Quiet on purpose — a divider between dates, not a banner.
    private func fieldNoteHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.focal(13))
                .foregroundStyle(Theme.textSecondary)
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
        }
        .textCase(nil)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func entryRow(_ entry: Entry) -> some View {
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
        }
        // Nothing was persisted — keep the row pending, don't count it, and say
        // so. The row has already animated out of the pending section.
        guard EntryPersistence.commit(
            message: EntryPersistence.confirmFailureMessage,
            save: { try modelContext.save() },
            rollback: { entry.isPending = true },
            report: undoStack.report
        ) else { return }
        // A share-sheet entry carries the date it was shared, which can be days
        // before the user gets round to confirming it. Its weekly bit belongs
        // to that day, not to today.
        CaptureBookkeeping.apply(
            modelContext: modelContext,
            categories: categories,
            categoryKey: entry.category,
            entryDate: entry.date
        )
        // A share-sheet item becomes a confirmed log only after this save. This
        // completes core onboarding just like a home capture, never while pending.
        OnboardingFlow.markCoreCompleteIfConfirmed(isPending: entry.isPending, isArchived: entry.isArchived)
        undoStack.record("Added \(Money.format(entry.amount))") {
            entry.isPending = true
            do {
                try modelContext.save()
            } catch {
                // The confirmation is still persisted — counters must stay as they are.
                Log.capture.error("Failed to persist undo of confirmation: \(Log.describe(error), privacy: .public)")
                return
            }
            CaptureBookkeeping.revert(modelContext: modelContext, categories: categories, categoryKey: entry.category, entryDate: entry.date)
        }
    }

    private func discardPending(_ entry: Entry) {
        let snapshot = (amount: entry.amount, category: entry.category, note: entry.note, date: entry.date)
        withAnimation(Motion.stateChange) {
            modelContext.delete(entry)
        }
        // `rollback` un-stages the delete and brings back the row itself.
        // Re-inserting a copy would put a different object on screen — same
        // numbers, new identity and new `createdAt` — which is not the entry
        // the user was looking at.
        guard EntryPersistence.commit(
            message: EntryPersistence.discardFailureMessage,
            save: { try modelContext.save() },
            rollback: { modelContext.rollback() },
            report: undoStack.report
        ) else { return }
        undoStack.record("Discarded pending entry") {
            let restored = Entry(
                amount: snapshot.amount,
                category: snapshot.category,
                note: snapshot.note,
                date: snapshot.date,
                isPending: true
            )
            modelContext.insert(restored)
            do {
                try modelContext.save()
            } catch {
                Log.capture.error("Failed to persist undo of discard: \(Log.describe(error), privacy: .public)")
            }
        }
    }

    // MARK: - Active / archived actions

    private func archive(_ entry: Entry) {
        withAnimation(Motion.stateChange) {
            entry.isArchived = true
        }
        guard EntryPersistence.commit(
            message: EntryPersistence.archiveFailureMessage,
            save: { try modelContext.save() },
            rollback: { entry.isArchived = false },
            report: undoStack.report
        ) else { return }
        // An archived entry is excluded from every count in the app, so the
        // counters it bumped when it was logged have to come back down with it.
        // Without this, archiving 40 of 45 entries left the recap still saying
        // "You've logged 45 expenses so far".
        CaptureBookkeeping.revert(
            modelContext: modelContext,
            categories: categories,
            categoryKey: entry.category,
            entryDate: entry.date
        )
        undoStack.record("Archived \(Money.format(entry.amount))") {
            entry.isArchived = false
            do {
                try modelContext.save()
            } catch {
                Log.capture.error("Failed to persist undo of archive: \(Log.describe(error), privacy: .public)")
                return
            }
            CaptureBookkeeping.apply(
                modelContext: modelContext,
                categories: categories,
                categoryKey: entry.category,
                entryDate: entry.date
            )
        }
    }

    private func unarchive(_ entry: Entry) {
        withAnimation(Motion.stateChange) {
            entry.isArchived = false
        }
        guard EntryPersistence.commit(
            message: EntryPersistence.unarchiveFailureMessage,
            save: { try modelContext.save() },
            rollback: { entry.isArchived = true },
            report: undoStack.report
        ) else { return }
        // Back in the counted set — the mirror of `archive` above.
        CaptureBookkeeping.apply(
            modelContext: modelContext,
            categories: categories,
            categoryKey: entry.category,
            entryDate: entry.date
        )
        undoStack.record("Restored \(Money.format(entry.amount))") {
            entry.isArchived = true
            do {
                try modelContext.save()
            } catch {
                Log.capture.error("Failed to persist undo of restore: \(Log.describe(error), privacy: .public)")
                return
            }
            CaptureBookkeeping.revert(
                modelContext: modelContext,
                categories: categories,
                categoryKey: entry.category,
                entryDate: entry.date
            )
        }
    }

    private func delete(_ entry: Entry) {
        let snapshot = DeletedEntrySnapshot(entry: entry)
        withAnimation(Motion.stateChange) {
            modelContext.delete(entry)
        }
        // See `discardPending`: rollback restores this row, not a look-alike.
        guard EntryPersistence.commit(
            message: EntryPersistence.deleteFailureMessage,
            save: { try modelContext.save() },
            rollback: { modelContext.rollback() },
            report: undoStack.report
        ) else { return }
        // Permanent removal from the counted set — but only if it was still in
        // it. Deleting an *archived* row is reachable from the Archived list,
        // and that row's counters already came down when it was archived;
        // reverting again would take them down twice. `revert` re-checks the
        // day itself, so the weekly bit only clears when this was that day's
        // last remaining entry.
        if !snapshot.isArchived {
            CaptureBookkeeping.revert(
                modelContext: modelContext,
                categories: categories,
                categoryKey: snapshot.category,
                entryDate: snapshot.date
            )
        }
        undoStack.record("Deleted \(Money.format(snapshot.amount))") {
            let restored = snapshot.makeEntry()
            modelContext.insert(restored)
            do {
                try modelContext.save()
            } catch {
                Log.capture.error("Failed to persist undo of delete: \(Log.describe(error), privacy: .public)")
                return
            }
            // Mirrors the guard above: a restored archived row rejoins the
            // Archived list, not the counted set.
            if !restored.isArchived {
                CaptureBookkeeping.apply(
                    modelContext: modelContext,
                    categories: categories,
                    categoryKey: restored.category,
                    entryDate: restored.date
                )
            }
        }
    }

    // MARK: - Debug

    private func clearAll() {
        let all = (try? modelContext.fetch(FetchDescriptor<Entry>())) ?? []
        for entry in all {
            modelContext.delete(entry)
        }
        guard EntryPersistence.commit(
            message: EntryPersistence.clearAllFailureMessage,
            save: { try modelContext.save() },
            rollback: { modelContext.rollback() },
            report: undoStack.report
        ) else { return }
        // A wiped history should also be a clean slate: counters, streaks,
        // and category usage all reset together.
        CaptureBookkeeping.resetCategoryUsage(modelContext: modelContext)
        StoreLocator.sharedDefaults.removeObject(forKey: "logsLogged")
        retention.resetAll()
        WidgetCenter.shared.reloadTimelines(ofKind: "SpendWidget")
    }
}

/// Everything a deleted entry needs to come back intact, so undo restores a
/// like-for-like row rather than a stripped copy.
///
/// A named type rather than an inline tuple because the field list is the thing
/// that goes wrong: `intent` was added to `Entry` after this path existed, and a
/// snapshot that quietly omits a field loses the user's answer at exactly the
/// moment they asked for it back. Mirrors `EditCategorySnapshot`, and is unit
/// tested for the same reason.
struct DeletedEntrySnapshot {
    let amount: Decimal
    let category: String
    let note: String?
    let date: Date
    let isArchived: Bool
    let intent: SpendIntent?

    init(entry: Entry) {
        amount = entry.amount
        category = entry.category
        note = entry.note
        date = entry.date
        isArchived = entry.isArchived
        intent = entry.intent
    }

    func makeEntry() -> Entry {
        Entry(
            amount: amount,
            category: category,
            note: note,
            date: date,
            isArchived: isArchived,
            intent: intent
        )
    }
}
