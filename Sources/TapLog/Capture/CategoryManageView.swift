import SwiftUI
import SwiftData

/// Add, edit, and delete spending categories. Deleting a category never touches
/// existing entries — they keep the category key string and display as "Other".
/// Tapping a row opens the editor, which is also where a per-category budget
/// (target + weekly/monthly reset) is configured.
struct CategoryManageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \SpendCategory.sortOrder) private var categories: [SpendCategory]

    @State private var showingAdd = false
    @State private var editingCategory: SpendCategory?

    var body: some View {
        NavigationStack {
            Group {
                if categories.isEmpty {
                    ContentUnavailableView(
                        "No categories",
                        systemImage: "tag",
                        description: Text("Add your first category to start logging.")
                    )
                } else {
                    List {
                        Section {
                            ForEach(categories) { category in
                                Button {
                                    editingCategory = category
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(category.emoji)
                                            .font(.title3)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(category.name)
                                                .foregroundStyle(.primary)
                                            if let subtitle = budgetSubtitle(for: category) {
                                                Text(subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(Theme.textSecondary)
                                                    .monospacedDigit()
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(Theme.textTertiary)
                                    }
                                }
                            }
                            .onDelete(perform: deleteCategories)
                        } footer: {
                            Text("Tap a category to rename it or set a weekly/monthly budget. Swipe left to remove a category — existing entries keep their data and show as Other.")
                        }
                    }
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddCategorySheet(existing: categories)
            }
            .sheet(item: $editingCategory) { category in
                EditCategorySheet(category: category)
            }
            .onAppear(perform: openRequestedCategoryForDebug)
        }
    }

    /// Dev hook in the style of `-route` / `-autolog`: opens one category's editor
    /// straight from `simctl launch`, so the budget preview card can be inspected
    /// without driving two sheets by hand.
    private func openRequestedCategoryForDebug() {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.lastIndex(of: "-editCategory"),
              args.indices.contains(index + 1) else { return }
        let key = args[index + 1]
        guard let match = categories.first(where: { $0.key == key }) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { editingCategory = match }
    }

    private func budgetSubtitle(for category: SpendCategory) -> String? {
        guard let target = category.budgetTarget, target > 0, let period = category.budgetPeriod else {
            return nil
        }
        let cadence = period == .monthly ? "month" : "week"
        return "\(Money.format(target)) / \(cadence)"
    }

    private func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(categories[index])
        }
        do {
            try modelContext.save()
        } catch {
            print("TapLog: Failed to delete categories: \(error)")
        }
    }
}

/// Edits an existing category's name, emoji, and optional budget. Values are
/// copied into local state and written back on Save so a cancelled edit never
/// half-mutates the model. A blank budget target clears the budget entirely;
/// a valid amount always sets target and period together, matching what
/// `BudgetCalculator.report(for:)` requires to treat the budget as configured.
struct EditCategorySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let category: SpendCategory

    @State private var name = ""
    @State private var emoji = ""
    @State private var budgetAmount: Decimal = 0
    @State private var period: BudgetPeriod = .weekly
    @State private var errorMessage: String?
    @State private var loaded = false
    @State private var previewState: TreeHealthMark = .noBudget

    @Query(filter: #Predicate<Entry> { !$0.isArchived && !$0.isPending }, sort: \Entry.date) private var entries: [Entry]

    private static let emojiSuggestions = ["☕️", "🍽️", "🚌", "🏠", "🛍️", "🧾", "🎉", "💊", "🎮", "🐶", "✈️", "📦"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Groceries", text: $name)
                }
                Section("Emoji") {
                    TextField("e.g. 🛒", text: $emoji)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        ForEach(Self.emojiSuggestions, id: \.self) { suggestion in
                            Button {
                                emoji = suggestion
                            } label: {
                                Text(suggestion)
                                    .font(.title3)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(
                                        emoji == suggestion
                                            ? Color.accentColor.opacity(0.2)
                                            : Color(.secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section {
                    // Stepper row with minus/plus buttons
                    HStack(spacing: 12) {
                        Button {
                            let step: Decimal = (period == .weekly) ? 50 : 250
                            budgetAmount = max(0, budgetAmount - step)
                            updatePreview()
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .frame(width: 52, height: 52)
                                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)

                        Spacer()
                        if budgetAmount > 0 {
                            Text(Money.format(budgetAmount))
                                .font(Theme.amount(38))
                                .foregroundStyle(Theme.textPrimary)
                        } else {
                            Text("None")
                                .font(Theme.amount(38))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        Spacer()

                        Button {
                            let step: Decimal = (period == .weekly) ? 50 : 250
                            budgetAmount = min(999999, budgetAmount + step)
                            updatePreview()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .frame(width: 52, height: 52)
                                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(height: 52)

                    Picker("Resets", selection: $period) {
                        Text("Weekly").tag(BudgetPeriod.weekly)
                        Text("Monthly").tag(BudgetPeriod.monthly)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: period) { _, _ in
                        updatePreview()
                    }

                    // Preview card
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            TreeMark(state: previewState, color: treeColor(for: previewState))
                                .frame(width: 60, height: 75)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(stateWord(for: previewState))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(treeColor(for: previewState))
                                Text(stateExplanation(for: previewState, spent: previewSpend))
                                    .font(.footnote)
                                    .foregroundStyle(Theme.textSecondary)
                            }

                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                    .transition(.opacity)

                    Text("Changing the target starts the tree over; past periods stay in history but stop counting toward this tree.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                } header: {
                    Text("Budget")
                } footer: {
                    Text("Spend limit per period. Set to zero for no budget.")
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                name = category.name
                emoji = category.emoji
                if let target = category.budgetTarget, category.budgetPeriod != nil {
                    budgetAmount = target
                }
                period = category.budgetPeriod ?? .weekly
                updatePreview()
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let original = EditCategorySnapshot(category: category)

        if budgetAmount > 0 {
            category.budgetTarget = budgetAmount
            category.budgetPeriod = period
        } else {
            category.budgetTarget = nil
            category.budgetPeriod = nil
        }

        category.name = trimmedName
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedEmoji.isEmpty {
            category.emoji = trimmedEmoji
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            original.restore(to: category)
            errorMessage = "Could not save: \(error.localizedDescription)"
        }
    }

    /// Spend in the period the user is *currently choosing*, not the one last saved.
    /// The preview has to answer "what will this budget do?", so it cannot go through
    /// `report(for:)` — that reads the persisted target and period.
    private var previewSpend: Decimal {
        let brackets = BudgetCalculator.intervals(for: period, calendar: .current, referenceDate: .now)
        let matches = BudgetCalculator.activeEntries(entries, matching: category.key, in: brackets.current)
        return BudgetCalculator.total(of: matches)
    }

    private func updatePreview() {
        guard budgetAmount > 0 else {
            withAnimation(Motion.gentle) {
                previewState = .noBudget
            }
            return
        }

        let spent = previewSpend

        let state: TreeHealthMark
        if spent > budgetAmount {
            state = .wilting
        } else if budgetAmount >= spent * 3 {
            state = .growing
        } else {
            state = .sprout
        }

        withAnimation(Motion.gentle) {
            previewState = state
        }
    }

    private func treeColor(for state: TreeHealthMark) -> Color {
        switch state {
        case .wilting:
            return Theme.clay
        case .noBudget:
            return Theme.textTertiary
        default:
            return Theme.accent
        }
    }

    private func stateWord(for state: TreeHealthMark) -> String {
        switch state {
        case .noBudget:
            return "No budget"
        case .wilting:
            let cadence = period == .monthly ? "month" : "week"
            return "Over this \(cadence)"
        case .growing:
            return "Steady"
        case .sprout:
            return "Recovering"
        default:
            return "Growing"
        }
    }

    private func stateExplanation(for state: TreeHealthMark, spent: Decimal) -> String {
        switch state {
        case .noBudget:
            return "This category will still log normally, it just won't grow a tree."
        case .wilting:
            let overspent = spent - budgetAmount
            return "You've spent \(Money.format(overspent)) over the budget."
        case .growing:
            return "This is a comfortable target — great pace."
        case .sprout:
            let remaining = budgetAmount - spent
            return "Recover this period by staying within the remaining \(Money.format(remaining))."
        default:
            return "Your spending is on track."
        }
    }
}

/// Captures the fields edited by `EditCategorySheet` so a failed persistence
/// operation cannot leave unsaved changes attached to the live model object.
struct EditCategorySnapshot {
    let name: String
    let emoji: String
    let budgetTarget: Decimal?
    let budgetPeriod: BudgetPeriod?
    let budgetHealthResetDate: Date?

    init(category: SpendCategory) {
        name = category.name
        emoji = category.emoji
        budgetTarget = category.budgetTarget
        budgetPeriod = category.budgetPeriod
        budgetHealthResetDate = category.budgetHealthResetDate
    }

    /// Writing `budgetTarget`/`budgetPeriod` re-fires their `didSet`, which stamps a
    /// fresh `budgetHealthResetDate`. Restoring must therefore put the original
    /// timestamp back *last* — otherwise a failed save would roll the values back
    /// while silently discarding the tree's history, which is the one thing the
    /// user could not see had happened.
    func restore(to category: SpendCategory) {
        category.name = name
        category.emoji = emoji
        category.budgetTarget = budgetTarget
        category.budgetPeriod = budgetPeriod
        category.budgetHealthResetDate = budgetHealthResetDate
    }
}

/// Selects any category from the compact capture screen while keeping category
/// creation and deletion available behind Manage.
struct CategoryPickerView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \SpendCategory.sortOrder) private var categories: [SpendCategory]

    let onSelect: (String) -> Void
    let onManage: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    Button {
                        onSelect(category.key)
                    } label: {
                        HStack(spacing: 12) {
                            Text(category.emoji)
                                .font(.title3)
                            Text(category.name)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Choose Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Manage") {
                        dismiss()
                        onManage()
                    }
                }
            }
        }
    }
}

struct AddCategorySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let existing: [SpendCategory]

    @State private var name = ""
    @State private var emoji = "🏷️"
    @State private var errorMessage: String?

    private static let emojiSuggestions = ["☕️", "🍽️", "🚌", "🏠", "🛍️", "🧾", "🎉", "💊", "🎮", "🐶", "✈️", "📦"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Groceries", text: $name)
                }
                Section("Emoji") {
                    TextField("e.g. 🛒", text: $emoji)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        ForEach(Self.emojiSuggestions, id: \.self) { suggestion in
                            Button {
                                emoji = suggestion
                            } label: {
                                Text(suggestion)
                                    .font(.title3)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(
                                        emoji == suggestion
                                            ? Color.accentColor.opacity(0.2)
                                            : Color(.secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func add() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextOrder = (existing.map(\.sortOrder).max() ?? 0) + 1
        // Keys still referenced by entries count as taken, so recreating a deleted
        // category name can't silently reattach that history to the new category.
        let takenByEntries = Set(
            ((try? modelContext.fetch(FetchDescriptor<Entry>())) ?? []).map(\.category)
        )
        let category = SpendCategory(
            key: SpendCategory.makeKey(forName: trimmedName, existing: existing, takenKeys: takenByEntries),
            name: trimmedName,
            emoji: trimmedEmoji.isEmpty ? "🏷️" : trimmedEmoji,
            sortOrder: nextOrder
        )
        modelContext.insert(category)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Could not save: \(error.localizedDescription)"
        }
    }
}
