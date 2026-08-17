import SwiftUI
import SwiftData

/// Step 2 — "make these categories yours", shown right after the first log so the user
/// has seen categories in context. Every chip starts selected (zero-effort default);
/// deselecting removes the category. Categories already used by an entry are locked
/// ("in use") so a first log never silently becomes "Other".
struct OnboardingCategoriesView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SpendCategory.sortOrder) private var categories: [SpendCategory]
    @Query private var entries: [Entry]

    let onContinue: () -> Void

    @State private var keepKeys: Set<String> = []
    @State private var showingAdd = false

    private var inUseKeys: Set<String> { Set(entries.map(\.category)) }

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Keep the ones you'll use.")
                    .font(.title3.bold())
                Text("You can change these anytime.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(categories) { category in
                        chip(category)
                    }
                    addChip
                }

                Spacer()

                Button {
                    applyAndContinue()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)

                Button("Skip") {
                    onContinue()
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
            .navigationTitle("Your categories")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            keepKeys = Set(categories.map(\.key))
        }
        .sheet(isPresented: $showingAdd, onDismiss: {
            // A category added here must survive the Continue pass.
            keepKeys.formUnion(categories.map(\.key))
        }) {
            AddCategorySheet(existing: categories)
        }
    }

    private func chip(_ category: SpendCategory) -> some View {
        let isKept = keepKeys.contains(category.key)
        let isInUse = inUseKeys.contains(category.key)

        return Button {
            if isInUse { return }
            if isKept {
                keepKeys.remove(category.key)
            } else {
                keepKeys.insert(category.key)
            }
        } label: {
            VStack(spacing: 4) {
                Text(category.emoji)
                    .font(.title3)
                Text(category.name)
                    .font(.caption)
                    .foregroundStyle(isKept ? Color.primary : .secondary)
                if isInUse {
                    Text("in use")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isKept ? Theme.accentSoft : Theme.surface,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isKept ? Theme.accent : .clear, lineWidth: 1.5)
            )
            .opacity(isKept || isInUse ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(isInUse)
    }

    private var addChip: some View {
        Button {
            showingAdd = true
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.title3)
                Text("Add yours")
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func applyAndContinue() {
        for category in categories where !keepKeys.contains(category.key) {
            modelContext.delete(category)
        }
        try? modelContext.save()
        onContinue()
    }
}
