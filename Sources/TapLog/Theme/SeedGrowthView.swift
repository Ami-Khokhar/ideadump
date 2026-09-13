import SwiftUI

/// The opening: a seed puts up two shoots, they lean apart as they climb, the
/// foliage unfurls behind the stroke, and the wordmark fades up. About 1.5s,
/// once, and then it holds.
///
/// It uses `VineArt.sprout()`, the same generator that draws the capture
/// screen's margins, so the launch screen and the screen it hands you to are
/// visibly the same plant.
///
/// This replaces a logo that scaled in and then breathed and rippled forever.
/// Growth has an end state, which is the point: the animation resolves and
/// stops competing with the screen behind it.
struct SeedGrowthView: View {
    /// Called once, on the frame the wordmark settles. The caller owns what
    /// happens next — here, dissolving through to the capture screen.
    ///
    /// It exists because the caller cannot time that itself: the animation does
    /// not start when this view appears, it starts when this view first draws.
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Pure and seeded, so it is built once rather than per frame.
    private static let plant = VineArt.sprout()

    /// How far behind the stroke a leaf finishes opening, as a fraction of the
    /// stem. Small enough that the foliage chases the tip rather than trailing
    /// it.
    private static let fadeBand: Double = 0.14

    /// The growth clock, started by the first frame that actually renders.
    @State private var clock = Clock()
    /// Stops the timeline once the plant is grown. Nothing here loops, so there
    /// is no reason to keep waking for frames after the last one.
    @State private var settled = false

    /// When growth started, latched on the first rendered frame.
    ///
    /// Deliberately not `onAppear`, which fires while iOS is still showing the
    /// launch image: measured from there the plant finished growing behind a
    /// white screen, and the first thing anyone actually saw was the tail of
    /// the dissolve. A `TimelineView` only ticks once the view is being drawn,
    /// so its first tick is the honest zero.
    ///
    /// A box rather than plain `@State` because the latch happens inside the
    /// draw closure, where mutating view state is not allowed. Nothing here
    /// needs to invalidate anything — the next tick reads it and moves on.
    private final class Clock {
        private var start: Date?

        /// Seconds since the first rendered frame. `onStart` runs once, when
        /// that frame arrives.
        func elapsed(at now: Date, onStart: () -> Void) -> TimeInterval {
            guard let start else {
                self.start = now
                onStart()
                return 0
            }
            return now.timeIntervalSince(start)
        }
    }

    var body: some View {
        GeometryReader { geo in
            if reduceMotion {
                // Already grown. Reduce Motion asks for no motion, not for less
                // content, so the finished plant is what appears.
                plant(Phase.grown, in: geo.size)
            } else {
                TimelineView(.animation(paused: settled)) { timeline in
                    let elapsed = clock.elapsed(at: timeline.date) { scheduleFinish() }
                    plant(Phase(elapsed: elapsed), in: geo.size)
                }
            }
        }
        // The plant is decoration. VoiceOver gets the name and nothing else.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("TapLog")
        .onAppear {
            guard reduceMotion else { return }
            onFinished()
        }
    }

    private func scheduleFinish() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Phase.duration) {
            onFinished()
            settled = true
        }
    }

    @ViewBuilder
    private func plant(_ phase: Phase, in size: CGSize) -> some View {
        let fit = GraphicsContext.vineFit(canvas: VineArt.canvas, in: size)

        ZStack {
            Canvas(opaque: false, rendersAsynchronously: false) { context, size in
                let fit = GraphicsContext.vineFit(canvas: VineArt.canvas, in: size)
                let scale = max(size.width / VineArt.canvas.width,
                                size.height / VineArt.canvas.height)

                // Ground and seed, first and lowest.
                context.stroke(
                    Self.plant.ground.applying(fit),
                    with: .color(Theme.bark.opacity(0.30 * phase.seed)),
                    style: StrokeStyle(lineWidth: 1.4 * scale, lineCap: .round)
                )
                let seed = Path(ellipseIn: CGRect(
                    x: Self.plant.seed.x - 5, y: Self.plant.seed.y - 6.2,
                    width: 10, height: 12.4
                ))
                context.fill(seed.applying(fit),
                             with: .color(Theme.bark.opacity(0.85 * phase.seed)))

                // Stems, drawn in progress.
                context.drawVines(Self.plant.stems, canvas: VineArt.canvas,
                                  in: size, color: Theme.moss, trim: phase.stem)

                // Foliage and tendrils, opening base to tip behind the stroke.
                context.drawVines(Self.plant.details, canvas: VineArt.canvas,
                                  in: size, color: Theme.moss,
                                  revealedThrough: phase.unfurl, fadeBand: Self.fadeBand)
            }
            .allowsHitTesting(false)

            Text("TapLog")
                .font(Theme.focal(40, weight: .regular))
                .foregroundStyle(Theme.ink)
                .position(CGPoint(x: 201, y: 746).applying(fit))
                .offset(y: 10 * (1 - phase.wordmark))
                .opacity(phase.wordmark)
        }
    }

    /// Where every moving part stands at one instant. Keeping the whole script
    /// in one place is what makes the 1.5s budget checkable by reading it.
    private struct Phase {
        let seed: Double
        let stem: Double
        let unfurl: Double
        let wordmark: Double

        /// First rendered frame to the last frame that changes anything.
        static let duration: TimeInterval = 1.50

        static let grown = Phase(seed: 1, stem: 1, unfurl: 1 + fadeBand, wordmark: 1)

        init(seed: Double, stem: Double, unfurl: Double, wordmark: Double) {
            self.seed = seed
            self.stem = stem
            self.unfurl = unfurl
            self.wordmark = wordmark
        }

        init(elapsed: TimeInterval) {
            seed = Phase.ramp(elapsed, start: 0, duration: 0.18)
            stem = Phase.ramp(elapsed, start: 0.14, duration: 1.15)
            // Overshoots 1 by the fade band so the last leaves at the tip reach
            // full opacity rather than stopping part-open.
            unfurl = Phase.ramp(elapsed, start: 0.30, duration: 1.10) * (1 + fadeBand)
            // Lands before the capture screen starts dissolving in over it, so
            // the name is legible on its own for a moment rather than arriving
            // already half-covered.
            wordmark = Phase.ramp(elapsed, start: 1.02, duration: 0.45)
        }

        /// Ease-out from 0 to 1 across one window of the script.
        private static func ramp(_ elapsed: TimeInterval, start: TimeInterval, duration: TimeInterval) -> Double {
            let t = min(max((elapsed - start) / duration, 0), 1)
            return 1 - pow(1 - t, 2.2)
        }
    }
}
