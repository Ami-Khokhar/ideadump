import SwiftUI
import AppIntents
import _AppIntents_SwiftUI

/// A concise, optional guide to the fastest capture surfaces. It never claims
/// that the app can invoke Siri for the user; the user starts the interaction.
struct SetupFrontDoorsView: View {
    @Environment(\.dismiss) private var dismiss

    /// Called when the user finishes the screen (Done or Not now). The deferred
    /// onboarding prompt uses this to persist its dismissal; the menu entry leaves it nil.
    var onDone: (() -> Void)? = nil

    @AppStorage(OnboardingFlow.openCaptureUsedKey, store: StoreLocator.sharedDefaults)
    private var usedOpenCapture = false
    @AppStorage(OnboardingFlow.directCaptureUsedKey, store: StoreLocator.sharedDefaults)
    private var usedDirectCapture = false
    @AppStorage(OnboardingFlow.logExpenseUsedKey, store: StoreLocator.sharedDefaults)
    private var usedHandsFree = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Faster ways to log")
                        .font(.title3.bold())

                    Text("Try one when it fits. TapLog stays out of your way until you ask it to log.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    captureCard
                    handsFreeCard
                    surfacesCard

                    Button {
                        finish()
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
            .navigationTitle("Faster ways")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { finish() }
                }
            }
        }
    }

    private var captureCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardTitle("Open the keypad", icon: "number.circle.fill", tint: .blue)
            Text("Say “Hey Siri, open capture in TapLog” or use the Action Button shortcut named Open Expense Capture. TapLog opens the keypad and focuses the amount.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let status = OnboardingFlow.directCaptureStatus(
                openCaptureUsed: usedOpenCapture,
                directCaptureUsed: usedDirectCapture
            ) {
                self.status(status)
            } else {
                Button("Try capture now (without Siri)") {
                    // This local fallback deliberately does not set Siri-use state.
                    OpenCaptureIntent.writePendingActivation()
                }
                .buttonStyle(.bordered)
            }

            if #available(iOS 16.0, *) {
                SiriTipView(intent: OpenCaptureIntent())
                    .siriTipViewStyle(.automatic)
                    .accessibilityLabel("Learn the Open the keypad Siri phrase")
            }
        }
        .cardSurface()
        .accessibilityElement(children: .contain)
    }

    private var handsFreeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardTitle("Log hands-free", icon: "mic.fill", tint: .purple)
            Text("Say “Hey Siri, log an expense in TapLog.” Siri asks for the amount, logs it without opening TapLog, and confirms the saved amount and category.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if usedHandsFree {
                status("Used")
            }

            if #available(iOS 16.0, *) {
                SiriTipView(intent: LogExpenseIntent())
                    .siriTipViewStyle(.automatic)
                    .accessibilityLabel("Learn the Log hands-free Siri phrase")
                ShortcutsLink()
                    .shortcutsLinkStyle(.automaticOutline)
                    .accessibilityLabel("Open TapLog actions in Shortcuts")
            }
        }
        .cardSurface()
        .accessibilityElement(children: .contain)
    }

    private var surfacesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardTitle("Other front doors", icon: "square.grid.2x2.fill", tint: .orange)
            Text("Home Screen: long-press → + → TapLog → add the widget.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Lock Screen: long-press → Customize → Lock Screen → Add Widgets → TapLog.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("iOS 18 Control Center: open Control Center → + → Add a Control → TapLog → Log expense.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Action Button (iPhone 15 Pro+): Settings → Action Button → Shortcut → Open Expense Capture.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("These are optional device-level setup steps; TapLog cannot open a specific Settings pane for you.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .cardSurface()
        .accessibilityElement(children: .combine)
    }

    private func cardTitle(_ title: String, icon: String, tint: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.bold())
            .foregroundStyle(tint)
    }

    private func status(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.accent)
    }

    private func finish() {
        onDone?()
        dismiss()
    }
}

private struct CardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}

private extension View {
    func cardSurface() -> some View { modifier(CardSurface()) }
}
