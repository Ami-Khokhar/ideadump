import SwiftUI

/// The one place that decides how motion degrades under Reduce Motion.
///
/// Without this, every call site would re-derive its own answer to "what do I
/// do when the user has Reduce Motion on?" — some would drop the animation,
/// some would keep a spring, some would forget the haptic. Deciding it once
/// here keeps that judgment consistent app-wide: motion stays brief and
/// purposeful, and confirmation never depends on an animation the user might
/// have turned off.
enum MotionPolicy {
    /// A short, plain fade to use in place of movement or growth when Reduce
    /// Motion is on. It exists so a state change still reads as a change,
    /// without sliding, scaling, or bouncing anything.
    private static let reducedFade = Animation.easeInOut(duration: 0.12)

    /// Returns `base` normally, or a short fade (or nil) under Reduce Motion.
    ///
    /// Pass the animation this call site would use when motion is fully on.
    /// Under Reduce Motion this returns a plain fade instead — never `base`
    /// itself, since `base` may carry movement or scale.
    static func animation(_ base: Animation?, reduceMotion: Bool) -> Animation? {
        reduceMotion ? reducedFade : base
    }

    /// Collapses a duration to a small constant under Reduce Motion.
    ///
    /// Use this where code drives a manual transition by duration rather than
    /// through `.animation(_:value:)` — the change should still resolve
    /// almost immediately, not vanish with zero visual feedback.
    static func duration(_ base: Double, reduceMotion: Bool) -> Double {
        reduceMotion ? 0.12 : base
    }

    /// The brief, one-shot settle for a post-save growth reaction — a plant
    /// nudging forward after an entry lands. Roughly half a second, on the
    /// same gentle timing curve as `Motion.gentle`, never springy or bouncy.
    ///
    /// This is a single reaction to a save, not a loop: it plays once and
    /// stops. See `maxDecorativeDuration` for why nothing here may loop.
    static let growthReaction = Animation.timingCurve(0.25, 0.55, 0.3, 1.0, duration: 0.6)

    /// Returns `growthReaction` normally, or a short fade (or nil) under
    /// Reduce Motion.
    ///
    /// The growth itself — the movement — is what this suppresses. The save
    /// it celebrates must still be confirmed some other way: a haptic and a
    /// line of copy, never the animation alone. Call sites are responsible
    /// for firing that confirmation regardless of what this returns.
    static func growth(reduceMotion: Bool) -> Animation? {
        reduceMotion ? reducedFade : growthReaction
    }

    /// Hard ceiling for any decorative animation in the app, in seconds.
    ///
    /// Nothing purely decorative — a growth reaction, an entrance, a settle —
    /// may run longer than this, and nothing decorative may loop. The user
    /// logs an entry many times a day; an animation that lingers, or one that
    /// repeats on its own, turns a brief acknowledgment into something they
    /// have to wait out.
    static let maxDecorativeDuration: Double = 0.8
}

/// Applies an animation the `MotionPolicy`-aware way: through this modifier
/// rather than a bare `.animation(_:value:)`, so Reduce Motion is handled at
/// the one call site that decides it, not re-derived at every use.
private struct MotionAware<Value: Equatable>: ViewModifier {
    var animation: Animation?
    var value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(MotionPolicy.animation(animation, reduceMotion: reduceMotion), value: value)
    }
}

extension View {
    /// Applies `animation`, degraded through `MotionPolicy` when the user has
    /// Reduce Motion on. Use this instead of `.animation(_:value:)` for any
    /// animation that carries movement, scale, or growth.
    func motionAware<Value: Equatable>(_ animation: Animation?, value: Value) -> some View {
        modifier(MotionAware(animation: animation, value: value))
    }
}
