import SwiftUI

/// A small circular progress ring showing how many days this week the user has
/// logged toward their target. Think Apple Watch Activity Rings — a visual "itch"
/// that creates Gestalt Closure motivation.
///
/// Size: 60pt. Placed on the home screen below the status line, above the zen stone.
struct WeeklyRingView: View {
    let progress: Double      // 0.0 … 1.0
    let daysLogged: Int
    let target: Int
    let freezesAvailable: Int

    private var isComplete: Bool { progress >= 1.0 }
    private var nearComplete: Bool { progress >= 0.8 && !isComplete }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background track.
                Circle()
                    .stroke(Theme.surface, lineWidth: 6)

                // Filled arc.
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(Motion.gentle, value: progress)

                // Center content.
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("\(daysLogged)/\(target)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                }
            }
            .frame(width: 60, height: 60)
            // Glow effect at 80%+ — the "almost there" visual tension.
            .shadow(
                color: nearComplete ? Theme.accent.opacity(0.25) : .clear,
                radius: 8, x: 0, y: 0
            )
            .overlay {
                if freezesAvailable > 0 && !isComplete {
                    // Small freeze indicator.
                    VStack {
                        Spacer()
                        HStack(spacing: 0) {
                            Spacer()
                            Text("❄️")
                                .font(.system(size: 9))
                        }
                    }
                    .frame(width: 60, height: 60)
                }
            }

            // Freeze count (only show if > 0 and not completed).
            if freezesAvailable > 0 && !isComplete {
                Text("\(freezesAvailable) freeze\(freezesAvailable == 1 ? "" : "s")")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .accessibilityLabel("Weekly progress: \(daysLogged) of \(target) days logged")
    }

    private var ringColor: Color {
        if isComplete { return Theme.accent }
        if freezesAvailable > 0 && daysLogged == 0 {
            // Gold tint when a freeze is protecting this week.
            return Color(red: 0.83, green: 0.63, blue: 0.09)
        }
        return Theme.accent
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        WeeklyRingView(progress: 0.4, daysLogged: 2, target: 5, freezesAvailable: 2)
        WeeklyRingView(progress: 0.8, daysLogged: 4, target: 5, freezesAvailable: 1)
        WeeklyRingView(progress: 1.0, daysLogged: 5, target: 5, freezesAvailable: 0)
    }
    .padding()
    .background(Theme.background)
}
