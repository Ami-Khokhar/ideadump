import SwiftUI

/// Step 0 — the single "welcome" beat. No tour, no account: one promise (5 seconds)
/// and one privacy line (everything stays on your phone), then straight to logging.
struct WelcomeView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("TapLog")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .entrance()

            Text("Track any expense in about 5 seconds.\nEverything stays on your phone.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
                .entrance(delay: 0.12)

            Spacer()

            Button {
                onContinue()
            } label: {
                Text("Log my first expense")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Theme.accent, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(ZenPress())
            .entrance(delay: 0.22)

            Button("Skip for now") {
                onSkip()
            }
            .font(.subheadline)
            .foregroundStyle(Theme.textTertiary)
            .padding(.top, 14)
            .entrance(delay: 0.3)

            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}
