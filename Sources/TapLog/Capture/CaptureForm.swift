import SwiftUI
import SwiftData
import WidgetKit

/// Edits one existing entry: amount, category, note.
///
/// This used to have a `create` mode as well, for a "+" toolbar button and the
/// deep-link/Siri/widget paths. Those all capture through `LogHomeView` now, and
/// nothing had constructed a `.create` form in a long time.
struct CaptureForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var undoStack: UndoStack

    @AppStorage("lastUsedCategory") private var lastUsedCategoryKey: String = SpendCategory.fallbackKey
    @Query(sort: \SpendCategory.sortOrder) private var categories: [SpendCategory]

    let entry: Entry

    @State private var amountText: String
    @State private var selectedCategoryKey: String
    @State private var note: String
    @State private var showAmountError = false
    @State private var amountFilterError: String?
    @State private var showingManageCategories = false
    @FocusState private var amountFocused: Bool

    init(entry: Entry) {
        self.entry = entry
        _amountText = State(initialValue: Money.plainString(entry.amount))
        _note = State(initialValue: entry.note ?? "")
        _selectedCategoryKey = State(initialValue: entry.category)
    }

    private var lookup: CategoryLookup { CategoryLookup(categories) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AmountTextField(
                        text: $amountText,
                        isFocused: $amountFocused,
                        placeholder: "0.00",
                        fontSize: AmountFont.fontSize(for: amountText),
                        onErrorChanged: { error in
                            amountFilterError = error
                            if error == nil { showAmountError = false }
                        }
                    )
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .contentShape(Rectangle())
                    .onTapGesture { requestAmountFocus() }
                    if let error = amountFilterError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else if showAmountError {
                        Text("Enter a valid amount greater than zero.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Amount")
                }

                Section("Category") {
                    if categories.isEmpty {
                        Text("No categories yet — add one with the + button.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories) { category in
                                categoryButton(category)
                            }
                            addCategoryButton
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Note") {
                    TextField("Optional", text: $note)
                }
        }
        .navigationTitle("Edit Entry")
        .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                requestAmountFocus()
            }
            .onChange(of: showingManageCategories) { _, isPresented in
                if !isPresented {
                    requestAmountFocus()
                }
            }
            .sheet(isPresented: $showingManageCategories) {
                CategoryManageView()
            }
        }
    }

    private func categoryButton(_ category: SpendCategory) -> some View {
        let isSelected = selectedCategoryKey == category.key
        return Button {
            selectedCategoryKey = category.key
            requestAmountFocus()
        } label: {
            VStack(spacing: 4) {
                Text(category.emoji)
                    .font(.title3)
                Text(category.name)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
            }
            .frame(minWidth: 58)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var addCategoryButton: some View {
        Button {
            showingManageCategories = true
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.title3)
                Text("Add")
                    .font(.caption)
            }
            .frame(minWidth: 58)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func save() {
        guard let amount = AmountInputFilter.parsedAmount(amountText) else {
            showAmountError = true
            requestAmountFocus()
            return
        }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryKey = selectedCategoryKey.isEmpty ? SpendCategory.fallbackKey : selectedCategoryKey

        let entry = self.entry
        let previous = (
            amount: entry.amount,
            category: entry.category,
            note: entry.note,
            isPending: entry.isPending
        )
        entry.amount = amount
        entry.category = categoryKey
        entry.note = trimmedNote.isEmpty ? nil : trimmedNote
        entry.isPending = false
        guard EntryPersistence.commit(
            message: EntryPersistence.editFailureMessage,
            save: { try modelContext.save() },
            rollback: {
                // Restore the in-memory state — nothing was persisted.
                entry.amount = previous.amount
                entry.category = previous.category
                entry.note = previous.note
                entry.isPending = previous.isPending
            },
            report: undoStack.report
        ) else { return }
        // Confirming a pending share-sheet entry is that expense's "log moment" —
        // count it exactly like any other capture (only once the save succeeded).
        if previous.isPending {
            lastUsedCategoryKey = categoryKey
            CaptureBookkeeping.apply(modelContext: modelContext, categories: categories, categoryKey: categoryKey)
            OnboardingFlow.markCoreCompleteIfConfirmed(isPending: entry.isPending, isArchived: entry.isArchived)
        }
        undoStack.record("Edited \(Money.format(amount)) · \(lookup.name(for: categoryKey))") {
            entry.amount = previous.amount
            entry.category = previous.category
            entry.note = previous.note
            entry.isPending = previous.isPending
            do {
                try modelContext.save()
            } catch {
                // The edit is still persisted — counters must stay as they are.
                print("TapLog: Failed to persist undo of edit: \(error)")
                return
            }
            if previous.isPending {
                CaptureBookkeeping.revert(modelContext: modelContext, categories: categories, categoryKey: categoryKey, entryDate: entry.date)
            }
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "SpendWidget")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func requestAmountFocus() {
        DispatchQueue.main.async {
            self.amountFocused = true
        }
    }
}
