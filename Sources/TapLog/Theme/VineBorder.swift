import SwiftUI

/// The climbing vines in the capture screen's margins.
///
/// Decoration, and treated as such: it is drawn behind everything, it never
/// takes a touch, and VoiceOver never reads it. The screen's job is one number,
/// so the vines stay in the outer strips and leave the amount, the category
/// line and the tiles alone.
struct VineBorder: View {
    /// Generated once per process rather than per redraw. The geometry is pure
    /// and seeded, so it cannot change between calls — building it every frame
    /// would only spend time to arrive at the same paths.
    private static let parts = VineArt.captureMargins()

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            context.drawVines(
                Self.parts,
                canvas: VineArt.canvas,
                in: size,
                color: Theme.moss
            )
        }
        // Fades out before the category line rather than stopping on one. A
        // hard edge would read as a crop; this reads as the plants receding
        // into the paper.
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: VineArt.fadeStart),
                    .init(color: .clear, location: VineArt.fadeEnd)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
