import SwiftUI

/// The streak's botanical mark: a laurel wreath that gains a leaf for every day
/// logged this week and closes when the weekly target is met.
///
/// ## Why a wreath, and not a tree
/// The app previously spoke two languages at once — budgets grew trees while the
/// streak burned a flame and filled an abstract ring. A flame beside a grove is a
/// mismatch, so the streak had to become botanical too. But it could not become a
/// *tree*: on the capture screen the streak sits two inches from `GroveStrip`, and
/// a small plant next to a row of small plants reads as one more category's
/// budget. The two signals are genuinely different — a streak counts whether you
/// logged, a tree measures spend against a target — and collapsing them visually
/// would make both unreadable.
///
/// So the wreath is deliberately a different *kind* of plant from every mark in
/// `TreeArt` / `TreeGlyphArt`:
/// - **Radial, not vertical.** Every tree is a trunk rising out of a ground
///   shadow. The wreath is a ring and stands on nothing.
/// - **Countable, not massed.** A crown is one blob whose size means something;
///   the wreath is *n* discrete leaves you can literally count.
/// - **Filled versus outlined**, never filled versus tinted — the difference
///   between a logged day and a missing one is a solid leaf against a hollow one,
///   which survives being seen in grey.
/// - **Open until it isn't.** The ring carries a gap at the top while the week is
///   unfinished and closes only when the target is met. That is the same Gestalt
///   "itch" the old progress ring traded on, kept intact through the change.
enum WreathArt {

    /// Design-time canvas the coordinates below are authored against. Square,
    /// unlike the trees' 4:5 — the wreath has no up.
    static let canvas = CGSize(width: 24, height: 24)

    private static let centre = CGPoint(x: 12, y: 12)
    /// Radius of the vine the leaves are attached to.
    private static let stemRadius: CGFloat = 7.6
    /// How far outside the vine a leaf is anchored.
    private static let leafOffset: CGFloat = 1.3
    /// Sky left open at the top while the week is unfinished. Wide enough to be
    /// unmistakable at 24pt, where a hairline gap just looks like a rendering seam.
    private static let gapDegrees: Double = 52

    /// One laurel leaf, tip at -y and centred near the origin so it can be
    /// rotated into place. Slimmer than `TreeGlyphArt.leaf`: leaves on a wreath
    /// are read individually rather than as a mass, so they need daylight between
    /// them at small sizes.
    private static let leaf: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -2.6))
        p.addCurve(to: CGPoint(x: 0.95, y: 1.55), control1: CGPoint(x: 1.25, y: -1.5), control2: CGPoint(x: 1.6, y: 0.25))
        p.addCurve(to: CGPoint(x: -0.95, y: 1.55), control1: CGPoint(x: 0.3, y: 2.4), control2: CGPoint(x: -0.3, y: 2.4))
        p.addCurve(to: CGPoint(x: 0, y: -2.6), control1: CGPoint(x: -1.6, y: 0.25), control2: CGPoint(x: -1.25, y: -1.5))
        p.closeSubpath()
        return p
    }()

    /// A point on the vine, `degrees` clockwise from the top of the ring.
    private static func point(atDegrees degrees: Double, radius: CGFloat) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(
            x: centre.x + radius * CGFloat(sin(radians)),
            y: centre.y - radius * CGFloat(cos(radians))
        )
    }

    /// A leaf sitting on the vine at `degrees`, laid along the arc and tilted
    /// outward — the laurel angle. Pointing them straight out from the centre
    /// instead turns the mark into a sunburst, which reads as a flower.
    private static func leaf(atDegrees degrees: Double, filled: Bool) -> TreeArt.TreePart {
        let anchor = point(atDegrees: degrees, radius: stemRadius + leafOffset)
        // A leaf drawn tip-up points along the tangent when rotated by
        // `degrees + 90`; backing off 40° from that tips it outward.
        let rotation = (degrees + 50) * .pi / 180
        return TreeArt.TreePart(
            path: leaf,
            transform: CGAffineTransform(translationX: anchor.x, y: anchor.y).rotated(by: rotation),
            // The hollow leaves have to carry a near-black ground as well as a
            // cream one, so they sit higher than a "ghosted" opacity would.
            opacity: filled ? 0.95 : 0.55,
            // A hollow leaf is the "not yet" state. Outline versus solid is a
            // difference of shape, so it still reads with colour taken away.
            lineWidth: filled ? 0 : 0.7
        )
    }

    /// The vine itself. Drawn all the way round once the target is met, so the
    /// closure the user is working toward actually happens on screen.
    private static func vine(closed: Bool) -> TreeArt.TreePart {
        var p = Path()
        if closed {
            p.addEllipse(in: CGRect(
                x: centre.x - stemRadius, y: centre.y - stemRadius,
                width: stemRadius * 2, height: stemRadius * 2
            ))
        } else {
            p.addArc(
                center: centre,
                radius: stemRadius,
                // Path angles run counter-clockwise from +x; the wreath's own
                // angles run clockwise from the top, hence the conversion.
                startAngle: .degrees(gapDegrees / 2 - 90),
                endAngle: .degrees(270 - gapDegrees / 2),
                clockwise: false
            )
        }
        return TreeArt.TreePart(path: p, transform: .identity, opacity: 0.45, lineWidth: 0.75)
    }

    /// Leaf slots for a weekly target, laid clockwise from just right of the top
    /// gap — the same direction the ring this replaces used to fill.
    private static func slotDegrees(total: Int) -> [Double] {
        guard total > 0 else { return [] }
        let span = 360 - gapDegrees
        let step = span / Double(total)
        return (0..<total).map { gapDegrees / 2 + step * (Double($0) + 0.5) }
    }

    /// `filled` leaves solid, the rest hollow. Days beyond the target don't add
    /// leaves — the wreath is full, and the streak's own copy carries the rest.
    static func parts(filled: Int, target: Int) -> [TreeArt.TreePart] {
        let slots = max(1, target)
        let grown = max(0, min(slots, filled))
        var parts = [vine(closed: grown >= slots)]
        for (index, degrees) in slotDegrees(total: slots).enumerated() {
            parts.append(leaf(atDegrees: degrees, filled: index < grown))
        }
        return parts
    }
}

/// Renders the streak wreath, scaled to fit and centred in its frame. Decorative
/// on its own — every caller states the count in words for VoiceOver.
struct WreathMark: View {
    let daysLogged: Int
    let target: Int
    let color: Color

    var body: some View {
        Canvas(opaque: false) { context, size in
            context.drawTree(
                WreathArt.parts(filled: daysLogged, target: target),
                canvas: WreathArt.canvas,
                in: size,
                color: color
            )
        }
        .accessibilityHidden(true)
    }
}

/// The streak's card-sized mark: the wreath with this week's count inside it,
/// plus the freeze status. Replaces the Apple-Watch-style progress ring that used
/// to sit here — same numbers, same freeze button, botanical vocabulary.
struct WeeklyStreakWreath: View {
    let daysLogged: Int
    let target: Int
    let freezesAvailable: Int

    private var isComplete: Bool { daysLogged >= target }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                WreathMark(daysLogged: daysLogged, target: target, color: Theme.accent)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("\(daysLogged)/\(target)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                }
            }
            .frame(width: 62, height: 62)
            .animation(Motion.gentle, value: daysLogged)

            // The freeze is called out in text rather than by tinting the wreath:
            // a gold ring said "protected" in colour alone, which is nothing at
            // all to a colourblind eye.
            if freezesAvailable > 0 && !isComplete {
                Text("\(freezesAvailable) freeze\(freezesAvailable == 1 ? "" : "s")")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Weekly progress: \(daysLogged) of \(target) days logged"
                + (freezesAvailable > 0 ? ", \(freezesAvailable) freeze\(freezesAvailable == 1 ? "" : "s") available" : "")
        )
    }
}

// MARK: - Preview

#Preview("Streak wreath") {
    VStack(spacing: 24) {
        HStack(spacing: 20) {
            ForEach(0...5, id: \.self) { day in
                WreathMark(daysLogged: day, target: 5, color: Theme.accent)
                    .frame(width: 24, height: 24)
            }
        }
        WeeklyStreakWreath(daysLogged: 2, target: 5, freezesAvailable: 2)
        WeeklyStreakWreath(daysLogged: 4, target: 5, freezesAvailable: 1)
        WeeklyStreakWreath(daysLogged: 5, target: 5, freezesAvailable: 0)
    }
    .padding()
    .background(Theme.background)
}
