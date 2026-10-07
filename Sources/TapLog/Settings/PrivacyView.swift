import SwiftUI

/// What TapLog does with your records, in the app, where it cannot 404.
///
/// The copy is data so a test asserts on what is rendered rather than grepping
/// the source. There is deliberately no link to a public policy page: none has
/// been approved for hosting, and a placeholder link that leads nowhere — or to
/// someone else's page — is worse than a screen that states the facts plainly.
/// When the owner approves a page, replace the last section and update the tests
/// that pin the pending state.
struct PrivacyView: View {
    /// The Settings row label, so the destination and its test share one string.
    static let settingsRowTitle = "Privacy"

    /// The screen's content, in order.
    static let sections: [(title: String, body: String)] = [
        (
            "Your records stay on this iPhone",
            "Entries, categories, budgets and streaks are stored on this device, in TapLog's own storage and the container it shares with the widget and the Share Sheet. TapLog has no account, no server and no analytics, and it does not send your spending anywhere."
        ),
        (
            "You control export and backup",
            "TapLog writes a CSV file only when you ask it to export, and only to the destination you choose. Once that file leaves TapLog, the copy is yours to keep or delete, and TapLog cannot reach it. Device backups are made by iOS through iCloud or your computer, not by TapLog."
        ),
        (
            "Apple handles payment",
            "Unlocking TapLog Pro and restoring a purchase both go through Apple's App Store. Apple processes the payment; TapLog is told only whether the purchase is valid, and never sees your card details."
        ),
        (
            "Siri, Shortcuts and the Action Button",
            "When you log by voice, through a Shortcut or from the Action Button, Apple's Shortcuts handles the request and hands it to TapLog, which writes the entry the same way as one you type."
        ),
        (
            "The Home Screen widget",
            "A tap on the widget runs TapLog's own code on this device and writes the entry straight into the same on-device store. Nothing leaves the device."
        ),
        (
            "Deleting your history",
            "Deleting all entries removes the records TapLog keeps on this device, including the copies the widget, the Share Sheet and the export use. It cannot remove a file you already exported or a backup you already made; delete those where they live."
        ),
        (
            "A public privacy policy",
            "This screen describes how TapLog behaves today. There is no link to a published policy page yet, because none has been approved for hosting. The link will be added here once that page exists."
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(Self.sections.indices, id: \.self) { index in
                    section(Self.sections[index].title, Self.sections[index].body)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Theme.background)
        .navigationTitle(Self.settingsRowTitle)
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
