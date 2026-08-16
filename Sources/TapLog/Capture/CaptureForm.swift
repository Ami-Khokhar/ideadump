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

    @AppStorage("lastUsedCategory") private var lastUsedCategoryKey: String = SpendCategory.defaultKey

    let mode: Mode

    @State private var amountText: String
    @State private var selectedCategoryKey: String
    @State private var note: String
    @State private var showAmountError = false
    @FocusState private var amountFocused: Bool

    init(mode: Mode, prefill: CapturePrefill = CapturePrefill()) {
        self.mode = mode
        switch mode {
        case .create:
            _amountText = State(initialValue: prefill.amountText ?? "")
            _note = State(initialValue: prefill.note ?? "")
            _selectedCategoryKey = State(initialValue: prefill.categoryKey ?? "")
        case .edit(let entry):
            _amountText = State(initialValue: Money.plainString(entry.amount))
            _note = State(initialValue: entry.note ?? "")
            _selectedCategoryKey = State(initialValue: entry.category)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .focused($amountFocused)
                    if showAmountError {
                        Text("Enter a valid amount greater than zero.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Amount")
                }

                Section("Category") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SpendCategory.all) { category in
                                categoryButton(category)
                            }
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
                if selectedCategoryKey.isEmpty {
                    selectedCategoryKey = lastUsedCategoryKey
                }
                amountFocused = true
            }
        }
    }

    private func categoryButton(_ category: SpendCategory) -> some View {
        let isSelected = selectedCategoryKey == category.key
        return Button {
            selectedCategoryKey = category.key
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

    private func save() {
        guard let amount = Money.parse(amountText), amount > 0 else {
            showAmountError = true
            return
        }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .create:
            let entry = Entry(
                amount: amount,
                category: selectedCategoryKey,
                note: trimmedNote.isEmpty ? nil : trimmedNote
            )
            modelContext.insert(entry)
            try? modelContext.save()
            lastUsedCategoryKey = selectedCategoryKey
            undoStack.record("Logged \(Money.format(amount)) · \(SpendCategory.name(for: selectedCategoryKey))") {
                modelContext.delete(entry)
                try? modelContext.save()
            }
        case .edit(let entry):
            let previous = (
                amount: entry.amount,
                category: entry.category,
                note: entry.note,
                isPending: entry.isPending
            )
            entry.amount = amount
            entry.category = selectedCategoryKey
            entry.note = trimmedNote.isEmpty ? nil : trimmedNote
            entry.isPending = false
            try? modelContext.save()
            undoStack.record("Edited \(Money.format(amount)) · \(SpendCategory.name(for: selectedCategoryKey))") {
                entry.amount = previous.amount
                entry.category = previous.category
                entry.note = previous.note
                entry.isPending = previous.isPending
                try? modelContext.save()
            }
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "SpendWidget")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
