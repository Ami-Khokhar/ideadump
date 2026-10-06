import SwiftUI

/// What TapLog does with your records, in the app, where it cannot 404.
///
/// There is deliberately no link to a public policy page: none has been approved
/// for hosting, and a placeholder link that leads nowhere — or to someone else's
/// page — is worse than a screen that states the facts plainly. When the owner
/// approves a page, add the link here; nothing else changes.
struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                section(
                    "Your records stay on this iPhone",
                    "Entries, categories, budgets and streaks are stored on this device, in TapLog's own storage and the container it shares with the widget and the Share Sheet. TapLog has no account, no server and no analytics, and it does not send your spending anywhere."
                )
                section(
                    "You control export and backup",
                    "TapLog writes a CSV file only when you ask it to export, and only to the destination you choose. Once that file leaves TapLog, the copy is yours to keep or delete, and TapLog cannot reach it. Device backups are made by iOS through iCloud or your computer, not by TapLog."
                )
                section(
                    "Apple handles payment",
                    "Unlocking TapLog Pro and restoring a purchase both go through Apple's App Store. Apple processes the payment; TapLog is told only whether the purchase is valid, and never sees your card details."
                )
                section(
                    "Siri, Shortcuts and the widget",
                    "When you log by voice, a Shortcut, the widget or the Action Button, Apple handles the request and hands the result to TapLog, which stores the entry the same way as one you type."
                )
                section(
                    "Deleting your history",
                    "Deleting all entries removes the records TapLog keeps on this device, including the copies the widget, the Share Sheet and the export use. It cannot remove a file you already exported or a backup you already made; delete those where they live."
                )
                section(
                    "A public privacy policy",
                    "This screen describes how TapLog behaves today. There is no link to a published policy page yet, because none has been approved for hosting. The link will be added here once that page exists."
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Theme.background)
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
