import SwiftUI

/// Concentric zen ripples — the visual echo of the TapLog logo.
///
/// In **ambient** mode (`burst = false`) a small number of soft rings breathe outward
/// continuously, never louder than 6 % opacity. In **burst** mode a short-lived set of
/// rings expands and fades quickly, confirming the log landed.
///
/// The view is zero-cost when hidden (`opacity(0)` / `.hidden()`).
struct RippleView: View {
    /// `true` for the short, punchy burst after a log; `false` for the endless ambient breathe.
    var burst: Bool = false

    /// Ambient: how many rings are alive at once.
    private let ambientRings = 3
    /// Burst: how many rings fire.
    private let burstRings = 4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxRadius = min(size.width, size.height) / 2

                let rings = burst ? burstRings : ambientRings
                let period: Double = burst ? 0.9 : 4.5          // seconds per full cycle
                let baseOpacity = burst ? 0.18 : 0.06

                for i in 0..<rings {
                    // Phase offset so rings are evenly distributed in the cycle.
                    let phase = Double(i) / Double(rings)
                    let t = ((now.remainder(dividingBy: period) / period) + phase).truncatingRemainder(dividingBy: 1.0)
                    // t goes 0→1 over one cycle. The ring grows from 0 % to 100 % of maxRadius.
                    let radius = maxRadius * t
                    // Fade in for the first 15 %, hold, then fade out in the last 30 %.
                    let alpha: Double
                    if t < 0.15 {
                        alpha = t / 0.15
                    } else if t > 0.70 {
                        alpha = max(0, (1.0 - t) / 0.30)
                    } else {
                        alpha = 1.0
                    }
                    let color = Color.accentColor.opacity(baseOpacity * alpha)
                    let lineWidth: CGFloat = burst ? 2.0 : 1.2

                    ctx.stroke(
                        Path(ellipseIn: CGRect(
                            x: center.x - radius,
                            y: center.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )),
                        with: .color(color),
                        lineWidth: lineWidth
                    )
                }
            }
        }
    }
}

// MARK: - Convenience

extension View {
    /// Overlays concentric zen ripples centred on this view.
    func zenRipples(burst: Bool = false) -> some View {
        overlay {
            RippleView(burst: burst)
                .allowsHitTesting(false)
        }
    }
}
