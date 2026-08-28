import SwiftUI

/// The badge-sized companion to `TreeMark`.
///
/// `TreeMark`'s artwork is drawn to be looked at: its states differ largely by
/// how much of the 64×80 canvas they fill, so a seedling is a few marks down by
/// the ground while a growing tree fills the frame. That reads beautifully at
/// 48pt and turns to porridge at 16 — the seedling shrinks to a speck of ink in
/// an empty box, and the crowns of `growing` and `wilting` collapse into the
/// same soft blob, leaving colour as the only difference. Colour alone is not a
/// difference: sage and clay are the same value to a colourblind eye.
///
/// So this mark trades detail for silhouette. Every state fills the same box and
/// is told apart by *shape* — crown full, crown thinned, crown gone, leaves
/// loose, stem short — which survives being shrunk to a 14pt corner badge and
/// survives being seen in grey.
///
/// It is also cheap: three to eight parts against `TreeMark`'s eighteen, which
/// matters when several of them sit on the capture screen and that screen
/// redraws on every keypad tap.
enum TreeGlyphArt {

    /// Design-time canvas the coordinates below are authored against. Same 4:5
    /// proportion as `TreeArt.canvas`, so a glyph and a full mark can share a
    /// layout without one of them sitting off its baseline.
    static let canvas = CGSize(width: 16, height: 20)

    /// Baseline the trees stand on, in canvas units.
    private static let groundY: CGFloat = 19
    /// Horizontal centre of the canvas.
    private static let midX: CGFloat = 8

    // MARK: - Primitives

    /// The soft shadow every state stands on. It is what makes "short" legible:
    /// without a ground line, a seedling just reads as a small tree drawn badly.
    private static let ground = Path(ellipseIn: CGRect(x: 3.6, y: 18.2, width: 8.8, height: 1.7))

    /// One leaf, centred on the origin so it can be rotated into place. A scaled
    /// echo of the leaf `TreeArt` uses, so the two marks share a vocabulary.
    private static let leaf: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -2.3))
        p.addCurve(to: CGPoint(x: 1.2, y: 1.8), control1: CGPoint(x: 1.5, y: -1.5), control2: CGPoint(x: 2, y: 0.3))
        p.addCurve(to: CGPoint(x: -1.2, y: 1.8), control1: CGPoint(x: 0.35, y: 2.8), control2: CGPoint(x: -0.35, y: 2.8))
        p.addCurve(to: CGPoint(x: 0, y: -2.3), control1: CGPoint(x: -2, y: 0.3), control2: CGPoint(x: -1.5, y: -1.5))
        p.closeSubpath()
        return p
    }()

    /// A leaf placed at `x`/`y`, tilted `degrees` and scaled by `scale`.
    private static func leaf(
        x: CGFloat,
        y: CGFloat,
        degrees: Double,
        scale: CGFloat = 1,
        opacity: Double = 1
    ) -> TreeArt.TreePart {
        TreeArt.TreePart(
            path: leaf,
            transform: CGAffineTransform(translationX: x, y: y)
                .rotated(by: degrees * .pi / 180)
                .scaledBy(x: scale, y: scale),
            opacity: opacity,
            lineWidth: 0
        )
    }

    /// A trunk tapering from the ground up to `topY`.
    private static func trunk(topY: CGFloat, opacity: Double = 1) -> TreeArt.TreePart {
        var p = Path()
        p.move(to: CGPoint(x: midX - 0.95, y: groundY))
        p.addLine(to: CGPoint(x: midX - 0.5, y: topY))
        p.addLine(to: CGPoint(x: midX + 0.5, y: topY))
        p.addLine(to: CGPoint(x: midX + 0.95, y: groundY))
        p.closeSubpath()
        return TreeArt.TreePart(path: p, transform: .identity, opacity: opacity, lineWidth: 0)
    }

    /// A soft-stemmed sprout stalk — stroked rather than filled, so the young
    /// states stay visibly slighter than the trunked ones.
    private static func stem(topY: CGFloat) -> TreeArt.TreePart {
        var p = Path()
        p.move(to: CGPoint(x: midX, y: groundY))
        p.addCurve(
            to: CGPoint(x: midX, y: topY),
            control1: CGPoint(x: midX - 0.5, y: groundY - 2),
            control2: CGPoint(x: midX + 0.4, y: topY + 2)
        )
        return TreeArt.TreePart(path: p, transform: .identity, opacity: 0.9, lineWidth: 1.05)
    }

    /// A crown blob. `growing` gets a tall, wide one; `wilting` a smaller one set
    /// lower on the trunk.
    private static func crown(_ rect: CGRect, opacity: Double) -> TreeArt.TreePart {
        TreeArt.TreePart(path: Path(ellipseIn: rect), transform: .identity, opacity: opacity, lineWidth: 0)
    }

    /// A bare branch, stroked from the trunk outward.
    private static func branch(
        from start: CGPoint,
        to end: CGPoint,
        width: CGFloat,
        opacity: Double
    ) -> TreeArt.TreePart {
        var p = Path()
        p.move(to: start)
        p.addQuadCurve(
            to: end,
            control: CGPoint(x: (start.x + end.x) / 2 + (end.x - start.x) * 0.15, y: (start.y + end.y) / 2 + 0.6)
        )
        return TreeArt.TreePart(path: p, transform: .identity, opacity: opacity, lineWidth: width)
    }

    private static let groundPart = TreeArt.TreePart(
        path: ground, transform: .identity, opacity: 0.14, lineWidth: 0
    )

    // MARK: - States

    static func parts(for state: TreeHealthMark) -> [TreeArt.TreePart] {
        switch state {
        case .noBudget:
            // Nothing to say — callers hide the glyph entirely rather than
            // drawing an empty plot of ground next to an unbudgeted category.
            return []

        case .seedling:
            // Short stem, two leaves, open sky above it: a start. Short is
            // relative to the crowned states rather than to the box — a mark
            // that only used the bottom third of its frame read as a speck at
            // strip size instead of as a young plant.
            return [
                groundPart,
                stem(topY: 11.4),
                leaf(x: 5.2, y: 11.3, degrees: -38, scale: 1.15, opacity: 0.95),
                leaf(x: 10.7, y: 12.6, degrees: 36, scale: 1.0, opacity: 0.85)
            ]

        case .sprout:
            // The same young stem carrying two more leaves and standing taller —
            // recovery reads as "further along", not as a different plant.
            return [
                groundPart,
                stem(topY: 7.6),
                leaf(x: 4.9, y: 11.6, degrees: -40, scale: 1.05, opacity: 0.9),
                leaf(x: 11.0, y: 12.4, degrees: 38, scale: 0.95, opacity: 0.8),
                leaf(x: 5.6, y: 7.5, degrees: -26, scale: 1.0, opacity: 0.95),
                leaf(x: 10.4, y: 8.4, degrees: 28, scale: 0.9, opacity: 0.85)
            ]

        case .growing:
            // Full round crown carried high on a trunk. The two leaves sit well
            // inside the crown: they are there to hint at the leaf-mass of the
            // full `TreeMark`, and any part of one that crosses the edge reads at
            // this size as a chip out of the silhouette rather than as texture.
            return [
                groundPart,
                trunk(topY: 9.2),
                crown(CGRect(x: 1.7, y: 1.3, width: 12.6, height: 11.4), opacity: 0.9),
                leaf(x: 4.9, y: 5.4, degrees: -32, scale: 0.85, opacity: 0.5),
                leaf(x: 11.1, y: 6.0, degrees: 30, scale: 0.85, opacity: 0.5)
            ]

        case .wilting:
            // Thinner crown, sitting lower, with two leaves drifting off it. The
            // tree is unmistakably still a tree: the copy promises it thins, not
            // that it dies, so nothing here is snapped, bare or crossed out.
            return [
                groundPart,
                trunk(topY: 10.4),
                crown(CGRect(x: 3.3, y: 4.4, width: 9.4, height: 7.6), opacity: 0.85),
                // The two loose leaves carry most of the difference from
                // `growing` at badge size, so they are drawn solidly enough to
                // survive a dark background — a ghosted leaf left the two states
                // separated by crown size alone at 14pt.
                leaf(x: 12.9, y: 13.4, degrees: 64, scale: 0.9, opacity: 0.78),
                leaf(x: 3.3, y: 15.4, degrees: -72, scale: 0.82, opacity: 0.62)
            ]

        case .resting:
            // Bare branches reaching up. No crown at all, which is the single
            // most obvious silhouette in the set — and the branches are open and
            // rising, the shape of a tree waiting for spring rather than a
            // dead one.
            return [
                groundPart,
                trunk(topY: 11.4),
                branch(from: CGPoint(x: 8, y: 12.2), to: CGPoint(x: 4.0, y: 7.0), width: 1.05, opacity: 0.9),
                branch(from: CGPoint(x: 8, y: 11.6), to: CGPoint(x: 12.1, y: 6.4), width: 1.05, opacity: 0.9),
                branch(from: CGPoint(x: 8, y: 14.6), to: CGPoint(x: 4.9, y: 11.4), width: 0.85, opacity: 0.7),
                branch(from: CGPoint(x: 8, y: 13.8), to: CGPoint(x: 11.3, y: 10.6), width: 0.85, opacity: 0.7),
                branch(from: CGPoint(x: 8, y: 11.0), to: CGPoint(x: 8.2, y: 6.2), width: 0.85, opacity: 0.75)
            ]
        }
    }
}

/// Renders a simplified tree mark, scaled to fit and centred in its frame.
/// Sized for badges and status rows; use `TreeMark` wherever the tree is big
/// enough to be the illustration rather than the indicator.
struct TreeStateGlyph: View {
    let state: TreeHealthMark
    let color: Color

    var body: some View {
        Canvas(opaque: false) { context, size in
            context.drawTree(TreeGlyphArt.parts(for: state), canvas: TreeGlyphArt.canvas, in: size, color: color)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Tree glyphs") {
    HStack(spacing: 14) {
        ForEach(
            Array([TreeHealthMark.seedling, .sprout, .growing, .wilting, .resting].enumerated()),
            id: \.offset
        ) { _, state in
            VStack(spacing: 10) {
                TreeStateGlyph(state: state, color: state == .wilting || state == .resting ? Theme.clay : Theme.accent)
                    .frame(width: 22, height: 28)
                TreeStateGlyph(state: state, color: state == .wilting || state == .resting ? Theme.clay : Theme.accent)
                    .frame(width: 14, height: 18)
            }
        }
    }
    .padding(30)
    .background(Theme.background)
}
