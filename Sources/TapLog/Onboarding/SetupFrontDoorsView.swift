import SwiftUI
import UIKit

/// Shown once, after the user has logged a few expenses: how to log without opening
/// the app. Purely informational — no permissions, no accounts.
struct SetupFrontDoorsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("One more thing 🎉")
                            .font(.title3.bold())
                        Text("Next time you won't even open the app to log an expense. Pick a front door:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    frontDoorCard(
                        icon: "square.grid.2x2",
                        tint: .blue,
                        title: "Home-screen widget",
                        body: "Long-press the home screen → tap + → search TapLog → add the medium widget. Then tap ☕️ or 🍽️ right on the widget to log instantly.",
                        footnote: "Works on every iPhone."
                    )

                    frontDoorCard(
                        icon: "mic.fill",
                        tint: .purple,
                        title: "Siri & Shortcuts",
                        body: "Say “Hey Siri, log twelve on coffee” — no app, no unlock needed. Or add the “Log Expense” action to any Shortcut.",
                        footnote: "Works on every iPhone."
                    ) {
                        Button {
                            openShortcuts()
                        } label: {
                            Label("Open Shortcuts", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.bordered)
                    }

                    frontDoorCard(
                        icon: "button.programmable",
                        tint: .orange,
                        title: "Action Button (iPhone 15 Pro+)",
                        body: "In Settings → Action Button → Shortcut, pick the “Log Expense” shortcut. One press on a locked phone logs the expense.",
                        footnote: "The closest thing to a dedicated capture button."
                    )

                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(20)
            }
            .navigationTitle("Log without TapLog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
        }
    }

    private func frontDoorCard(
        icon: String,
        tint: Color,
        title: String,
        body: String,
        footnote: String,
        @ViewBuilder extra: () -> some View = { EmptyView() }
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.bold())
                Text(body)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if footnote != "" {
                    Text(footnote)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                extra()
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func openShortcuts() {
        guard let url = URL(string: "shortcuts://") else { return }
        UIApplication.shared.open(url)
    }
}
