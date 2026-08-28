import SwiftUI
import SwiftData
import WidgetKit

/// The single capture form. Every entry point (toolbar "+", deep link, widget, Siri and
/// Shortcuts) lands here, pre-filled. Logging is at most three taps: type amount, tap
/// category, tap Log.
struct CaptureForm: View {
    enum Mode {
        case create
        case edit(Entry)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var undoStack: UndoStack

    @AppStorage("lastUsedCategory") private var lastUsedCategoryKey: String = SpendCategory.fallbackKey
    @Query(sort: \SpendCategory.sortOrder) private var categories: [SpendCategory]

    let mode: Mode
    let isOnboarding: Bool
    /// When set (onboarding Step 1), a successful log advances the flow instead of
    /// dismissing the form.
    let onLogged: (() -> Void)?

    @State private var amountText: String
    @State private var selectedCategoryKey: String
    @State private var prefillCategoryQuery: String
    @State private var note: String
    @State private var showAmountError = false
    @State private var amountFilterError: String?
    @State private var showingManageCategories = false
    @FocusState private var amountFocused: Bool

    init(
        mode: Mode,
        prefill: CapturePrefill = CapturePrefill(),
        isOnboarding: Bool = false,
        onLogged: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.isOnboarding = isOnboarding
        self.onLogged = onLogged
        switch mode {
        case .create:
            _amountText = State(initialValue: prefill.amountText ?? "")
            _note = State(initialValue: prefill.note ?? "")
            _prefillCategoryQuery = State(initialValue: prefill.categoryQuery ?? "")
            _selectedCategoryKey = State(initialValue: "")
        case .edit(let entry):
            _amountText = State(initialValue: Money.plainString(entry.amount))
            _note = State(initialValue: entry.note ?? "")
            _prefillCategoryQuery = State(initialValue: "")
            _selectedCategoryKey = State(initialValue: entry.category)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
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
        .navigationTitle(isEditing ? "Edit Entry" : "Log Expense")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top, spacing: 0) {
            if isOnboarding {
                onboardingHeader
            }
        }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Log") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                resolveCategory()
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

    /// Picks the category to pre-select: deep-link/Siri hint first, then the last-used
    /// one if it still exists, then the first available.
    private func resolveCategory() {
        if !prefillCategoryQuery.isEmpty {
            let query = prefillCategoryQuery.lowercased()
            if let match = categories.first(where: {
                $0.key.lowercased() == query || $0.name.lowercased() == query
            }) {
                selectedCategoryKey = match.key
                return
            }
        }
        if let lastUsed = categories.first(where: { $0.key == lastUsedCategoryKey }) {
            selectedCategoryKey = lastUsed.key
            return
        }
        selectedCategoryKey = categories.first?.key ?? ""
    }

    private var onboardingHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.tap.fill")
                .foregroundStyle(.tint)
            Text("Your first expense — type the amount, tap Log. About 5 seconds.")
                .font(.footnote)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thinMaterial)
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

        switch mode {
        case .create:
            let entry = Entry(
                amount: amount,
                category: categoryKey,
                note: trimmedNote.isEmpty ? nil : trimmedNote
            )
            modelContext.insert(entry)
            guard EntryPersistence.commit(
                message: EntryPersistence.insertFailureMessage,
                save: { try modelContext.save() },
                rollback: { modelContext.delete(entry) },
                report: undoStack.report
            ) else { return }
            lastUsedCategoryKey = categoryKey
            CaptureBookkeeping.apply(modelContext: modelContext, categories: categories, categoryKey: categoryKey)
            undoStack.record("Logged \(Money.format(amount)) · \(lookup.name(for: categoryKey))") {
                modelContext.delete(entry)
                do {
                    try modelContext.save()
                } catch {
                    // The entry is still persisted — counters must stay as they are.
                    print("TapLog: Failed to persist undo of entry: \(error)")
                    return
                }
                CaptureBookkeeping.revert(modelContext: modelContext, categories: categories, categoryKey: categoryKey, entryDate: entry.date)
            }
        case .edit(let entry):
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
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "SpendWidget")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if let onLogged {
            onLogged()
        } else {
            dismiss()
        }
    }

    private func requestAmountFocus() {
        DispatchQueue.main.async {
            self.amountFocused = true
        }
    }
}
