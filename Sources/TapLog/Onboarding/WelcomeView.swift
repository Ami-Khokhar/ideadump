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
                .font(Theme.focal(40, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .entrance()

            Text("Track any expense in about 5 seconds.\nEverything stays on your phone.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
                .entrance(delay: 0.12)

            GrowthSequence()
                .padding(.top, 28)
                .entrance(delay: 0.2)

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
            .buttonStyle(PressStyle())
            .entrance(delay: 0.28)

            Button("Skip for now") {
                onSkip()
            }
            .font(.subheadline)
            .foregroundStyle(Theme.textTertiary)
            .padding(.top, 14)
            .entrance(delay: 0.34)

            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PaperGround())
    }
}

/// One beat of the welcome screen's authored seed → sprout → tree explanation.
private struct GrowthStage {
    let mark: TreeHealthMark
    let caption: String
}

/// The metaphor taught once, in the app's observant, non-punitive voice: a
/// budget starts small, grows as it's used, and never dies — it only rests.
private let growthStages: [GrowthStage] = [
    GrowthStage(mark: .seedling, caption: "A budget starts as a seedling."),
    GrowthStage(mark: .sprout, caption: "Log as you spend, and it grows."),
    GrowthStage(mark: .growing, caption: "Overspend, and it simply rests — no tree ever dies.")
]

/// The welcome screen's one authored illustration: seed → sprout → tree,
/// played once and never again.
///
/// This teaches the app's core metaphor before the user has planted anything,
/// so the first real tree they see later already means something. It is
/// strictly decorative — the caption text carries the explanation on its own,
/// and nothing here ever gates `onContinue`/`onSkip` above it: the sequence
/// runs on its own clock while the buttons stay tappable throughout.
///
/// Under Reduce Motion the three stages render as a static, unanimated row
/// (or column, at accessibility type sizes) so the full explanation is on
/// screen at once instead of behind a timed reveal.
private struct GrowthSequence: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var stageIndex = 0
    @State private var playTask: Task<Void, Never>?

    /// Hold time between stages. Three stages resolve in well under two
    /// seconds each, comfortably inside `MotionPolicy.maxDecorativeDuration`
    /// for the transition itself, and the sequence never loops back to 0.
    private static let holdNanoseconds: UInt64 = 900_000_000

    var body: some View {
        Group {
            if reduceMotion {
                staticStages
            } else {
                animatedStage
            }
        }
        .onAppear(perform: startIfNeeded)
        .onDisappear {
            playTask?.cancel()
            playTask = nil
        }
    }

    private var animatedStage: some View {
        VStack(spacing: 10) {
            TreeMark(state: growthStages[stageIndex].mark, color: Theme.moss)
                .frame(width: 56, height: 70)
                .id(stageIndex)
                .transition(.opacity)

            Text(growthStages[stageIndex].caption)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 260)
        }
    }

    private var staticStages: some View {
        let columns = ForEach(growthStages.indices, id: \.self) { index in
            VStack(spacing: 8) {
                TreeMark(state: growthStages[index].mark, color: Theme.moss)
                    .frame(width: 40, height: 50)
                Text(growthStages[index].caption)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }

        // At accessibility type sizes three columns of wrapped text would
        // crowd each other; stacking them keeps every caption legible
        // instead of shrinking the text to fit.
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 20) { columns }
            } else {
                HStack(alignment: .top, spacing: 18) { columns }
            }
        }
    }

    private func startIfNeeded() {
        guard !reduceMotion, playTask == nil else { return }
        playTask = Task {
            for index in growthStages.indices.dropFirst() {
                try? await Task.sleep(nanoseconds: Self.holdNanoseconds)
                guard !Task.isCancelled else { return }
                withAnimation(MotionPolicy.animation(.easeInOut(duration: 0.35), reduceMotion: reduceMotion)) {
                    stageIndex = index
                }
            }
        }
    }
}
