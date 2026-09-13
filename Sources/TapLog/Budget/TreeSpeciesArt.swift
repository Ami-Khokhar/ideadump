import SwiftUI

/// Gives each `TreeSpecies` its own posture without re-authoring any artwork.
///
/// `TreeArt` owns the real geometry (leaves, trunk, canopy) and keeps it private,
/// so this file cannot reach in and redraw a species from scratch. Instead it
/// takes the parts `TreeArt.parts(for:)` already built and stretches the whole
/// tree about its trunk base — narrower and taller for a poplar-like column,
/// wider and shorter for a broad canopy. The grove reads as mixed species even
/// though every leaf and branch still traces back to one authored family.
enum TreeSpeciesArt {

    /// Every tree in `TreeArt` stands on this point, so it is the pivot a
    /// species stretch has to hold fixed — otherwise a taller tree would float
    /// above the ground line instead of growing from it.
    private static let trunkBase = CGPoint(x: 32, y: 72.5)

    /// Horizontal and vertical stretch for each species, applied about `trunkBase`.
    private static func scale(for species: TreeSpecies) -> (x: CGFloat, y: CGFloat) {
        switch species {
        case .rounded:
            return (1, 1)
        case .columnar:
            return (0.78, 1.12)
        case .spreading:
            return (1.18, 0.92)
        }
    }

    /// The anchor-based stretch for `species`: move the trunk base to the
    /// origin, scale, then move it back, so the base itself never shifts.
    private static func speciesTransform(for species: TreeSpecies) -> CGAffineTransform {
        let (sx, sy) = scale(for: species)
        return CGAffineTransform(translationX: -trunkBase.x, y: -trunkBase.y)
            .concatenating(CGAffineTransform(scaleX: sx, y: sy))
            .concatenating(CGAffineTransform(translationX: trunkBase.x, y: trunkBase.y))
    }

    /// `TreeArt.parts(for: state)`, restyled for `species`.
    ///
    /// Each part keeps its own authored transform and only gains the species
    /// stretch on top of it, composed in canvas space so the whole tree — trunk,
    /// canopy copies, everything — moves as one rigid silhouette.
    static func parts(for state: TreeHealthMark, species: TreeSpecies) -> [TreeArt.TreePart] {
        let stretch = speciesTransform(for: species)
        let (sx, sy) = scale(for: species)
        // A non-uniform scale would thicken strokes on one axis and thin them on
        // the other. Scaling lineWidth by the geometric mean keeps every stroke
        // reading as the same weight regardless of which way the tree stretched.
        let lineWidthScale = (sx * sy).squareRoot()

        return TreeArt.parts(for: state).map { part in
            TreeArt.TreePart(
                path: part.path,
                transform: part.transform.concatenating(stretch),
                opacity: part.opacity,
                lineWidth: part.lineWidth * lineWidthScale
            )
        }
    }

    /// Always `TreeArt.canvas` — the species stretch is anchored inside that
    /// same 64×80 frame, so no species needs a different canvas to fit in.
    static func canvas(for species: TreeSpecies) -> CGSize {
        TreeArt.canvas
    }
}

/// Renders a species-aware tree mark, scaled to fit and centred in the frame it is given.
///
/// This is `TreeMark` plus a `species`, kept as a separate view so callers that
/// don't care about species (like the plain health legend) can keep using
/// `TreeMark` unchanged.
struct SpeciesTreeMark: View {
    let state: TreeHealthMark
    let species: TreeSpecies
    let color: Color

    var body: some View {
        Canvas(opaque: false) { context, size in
            context.drawTree(TreeSpeciesArt.parts(for: state, species: species), canvas: TreeArt.canvas, in: size, color: color)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    let species: [TreeSpecies] = [.rounded, .columnar, .spreading]
    let states: [TreeHealthMark] = [.seedling, .growing, .resting]

    return VStack(spacing: 16) {
        ForEach(Array(states.enumerated()), id: \.offset) { _, state in
            HStack(spacing: 16) {
                ForEach(Array(species.enumerated()), id: \.offset) { _, species in
                    SpeciesTreeMark(state: state, species: species, color: .green)
                        .frame(width: 64, height: 80)
                }
            }
        }
    }
    .padding()
}
