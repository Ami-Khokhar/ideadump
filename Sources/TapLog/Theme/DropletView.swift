import SwiftUI

/// A single water droplet that falls from above and lands in the centre of the zen stone.
/// On impact it vanishes — the RippleView burst handles the splash.
///
/// **Ambient mode**: drips on a slow timer (≈ 5 s cycle), like a zen garden water feature.
/// **Trigger mode**: increment `triggerID` to fire a single drop immediately (used on log).
struct DropletView: View {
    /// When `true`, the drop falls on a periodic cycle. When `false`, only `triggerID` fires it.
    var ambient: Bool = true

    /// Increment this to fire a single drop immediately.
    var triggerID: Int = 0

    @State private var progress: CGFloat = 0
    @State private var isVisible = false
    @State private var lastTriggerID: Int = 0

    private let fallDuration: Double = 0.55
    private let fallDistance: CGFloat = 36

    var body: some View {
        Canvas { ctx, size in
            guard isVisible else { return }

            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let dropRadius: CGFloat = 4

            // Drop position: starts above centre, falls to centre.
            let y = center.y - fallDistance + (fallDistance * progress)

            // Squash + fade on impact (last 10% of travel).
            let impactProgress = Double(progress)
            let scale: CGFloat
            let alpha: Double
            if impactProgress > 0.9 {
                let t = (impactProgress - 0.9) / 0.1  // 0→1 in last 10%
                scale = 1.0 + CGFloat(t) * 0.6        // squash wider
                alpha = 1.0 - t                        // fade out
            } else {
                scale = 1.0
                alpha = min(1.0, impactProgress / 0.15) // fade in over first 15%
            }

            // Teardrop: slightly taller than wide at start, flattens on impact.
            let w = dropRadius * 2 * scale
            let h = dropRadius * 2 / scale
            let rect = CGRect(x: center.x - w/2, y: y - h/2, width: w, height: h)
            let path = Path(ellipseIn: rect)

            ctx.fill(path, with: .color(Theme.accent.opacity(0.5 * alpha)))

            // Tiny highlight dot on the upper third of the drop.
            let highlightY = y - h * 0.2
            let hlRect = CGRect(x: center.x - 1.5, y: highlightY - 1, width: 3, height: 2)
            ctx.fill(Path(ellipseIn: hlRect), with: .color(.white.opacity(0.35 * alpha)))
        }
        .allowsHitTesting(false)
        .onChange(of: triggerID) { oldValue, newValue in
            guard newValue != oldValue else { return }
            fireDrop()
        }
        .onAppear {
            if ambient { startAmbientLoop() }
        }
    }

    // MARK: - Animation

    private func fireDrop() {
        progress = 0
        withAnimation(.easeIn(duration: fallDuration)) {
            progress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + fallDuration + 0.05) {
            isVisible = false
            progress = 0
        }
        isVisible = true
    }

    private func startAmbientLoop() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            dripLoop()
        }
    }

    private func dripLoop() {
        guard ambient else { return }
        fireDrop()
        DispatchQueue.main.asyncAfter(deadline: .now() + fallDuration + 5.0) {
            dripLoop()
        }
    }
}
