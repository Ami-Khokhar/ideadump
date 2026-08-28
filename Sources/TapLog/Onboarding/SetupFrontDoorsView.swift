import SwiftUI
import UIKit
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

    /// The four device-level surfaces, so at most one row is expanded at a time.
    private enum FrontDoor { case homeScreen, lockScreen, controlCenter, actionButton }

    @State private var expandedDoor: FrontDoor?
    @StateObject private var inventory = FrontDoorInventory()
    @State private var surfacesExpanded = false

    /// How many surfaces iOS confirms are in place, or nil while nothing is
    /// known yet. Shown on the collapsed header so the card can report progress
    /// without being opened.
    private var addedCount: Int? {
        let known = [inventory.hasHomeScreenWidget, inventory.hasLockScreenWidget, inventory.hasControl]
            .compactMap { $0 }
        guard !known.isEmpty else { return nil }
        return known.filter { $0 }.count
    }

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
            cardTitle("Open the keypad", icon: "number.circle.fill", tint: Theme.accent)
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
            cardTitle("Log hands-free", icon: "mic.fill", tint: Theme.clay)
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

    /// The four device-level surfaces, as a compact list rather than four
    /// standing instruction chains.
    ///
    /// Every row used to print its full "long-press → + → TapLog" sequence at
    /// all times, so the card was nine lines of imperative text that stayed
    /// identical after the user had followed them. Now each row states what the
    /// surface *is* and reveals its steps only when tapped, and the three we can
    /// ask iOS about collapse to "Added" once they're in place.
    private var surfacesCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(Motion.gentleFast) { surfacesExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    cardTitle("Other front doors", icon: "square.grid.2x2.fill", tint: Theme.accent)
                    Spacer(minLength: 8)
                    if let added = addedCount, added > 0 {
                        Text("\(added) added")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .rotationEffect(.degrees(surfacesExpanded ? 0 : -90))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(surfacesExpanded ? "Hides the list" : "Shows the list")

            if !surfacesExpanded {
                // Collapsed, the card is two lines instead of a screenful. The
                // four surfaces are genuinely optional, so the default state
                // names them and gets out of the way.
                Text("Widgets, Control Center and the Action Button.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
            }

            if surfacesExpanded {
                frontDoorRow(
                    id: .homeScreen,
                    title: "Home Screen widget",
                    summary: "Today's total, one tap from the keypad.",
                    installed: inventory.hasHomeScreenWidget,
                    steps: "Long-press the Home Screen, tap +, search TapLog, then add the widget."
                )
                frontDoorRow(
                    id: .lockScreen,
                    title: "Lock Screen widget",
                    summary: "Log without unlocking first.",
                    installed: inventory.hasLockScreenWidget,
                    steps: "Long-press the Lock Screen, tap Customize, choose Lock Screen, then Add Widgets and pick TapLog."
                )
                if #available(iOS 18.0, *) {
                    frontDoorRow(
                        id: .controlCenter,
                        title: "Control Center",
                        summary: "A swipe down from anywhere.",
                        installed: inventory.hasControl,
                        steps: "Open Control Center, tap +, then Add a Control, and choose TapLog's Log expense."
                    )
                }
                frontDoorRow(
                    id: .actionButton,
                    title: "Action Button",
                    summary: "iPhone 15 Pro and later.",
                    // There is no API to ask whether a Shortcut is bound to the
                    // Action Button, so this row never claims to know.
                    installed: nil,
                    steps: "Settings → Action Button → Shortcut → Open Expense Capture."
                )

                Text("These steps happen in iOS. TapLog can't open a Settings pane for you.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 8)
            }
        }
        .cardSurface()
        .task { await inventory.refresh() }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didBecomeActiveNotification
        )) { _ in
            // The user leaves for Settings or the Home Screen to do any of
            // this, so coming back is the moment the answer has changed.
            Task { await inventory.refresh() }
        }
    }

    /// One surface: name and one-line purpose always visible, steps on demand,
    /// or a checkmark when iOS confirms it is already in place.
    private func frontDoorRow(
        id: FrontDoor,
        title: String,
        summary: String,
        installed: Bool?,
        steps: String
    ) -> some View {
        let isAdded = installed == true
        let isExpanded = expandedDoor == id

        return VStack(alignment: .leading, spacing: 6) {
            Button {
                guard !isAdded else { return }
                withAnimation(Motion.gentleFast) {
                    expandedDoor = isExpanded ? nil : id
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer(minLength: 8)
                    if isAdded {
                        Label("Added", systemImage: "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    } else {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textTertiary)
                            .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isAdded)
            .accessibilityHint(isAdded ? "" : (isExpanded ? "Hides the steps" : "Shows the steps"))

            if isExpanded && !isAdded {
                Text(steps)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
        }
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
