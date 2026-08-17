import SwiftUI
import SwiftData

/// Add and delete spending categories. Deleting a category never touches existing
/// entries — they keep the category key string and display as "Other".
struct CategoryManageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \SpendCategory.sortOrder) private var categories: [SpendCategory]

    @State private var showingAdd = false

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
                                HStack(spacing: 12) {
                                    Text(category.emoji)
                                        .font(.title3)
                                    Text(category.name)
                                }
                            }
                            .onDelete(perform: deleteCategories)
                        } footer: {
                            Text("Swipe left to remove a category. Existing entries keep their data and show as Other.")
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
        }
    }

    private func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(categories[index])
        }
        try? modelContext.save()
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
        let category = SpendCategory(
            key: SpendCategory.makeKey(forName: trimmedName, existing: existing),
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
