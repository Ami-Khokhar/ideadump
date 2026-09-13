import SwiftUI

/// Paints the field-journal background: an adaptive paper fill plus a very faint,
/// static fibrous grain texture. The grain is deterministic, drawn once at the given
/// size, never changing between renders — it reads as part of the surface, not a bug.
struct PaperGround: View {
    /// Seeds the grain generator so the same speckle pattern draws every time.
    /// A fixed seed ensures the texture is stable across render cycles and devices.
    private let seed: UInt32 = 42

    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)

            // Fill the background with paper color.
            context.fill(
                Path(bounds),
                with: .color(Theme.paper)
            )

            // Draw the grain texture with deterministic pseudo-random placement.
            drawGrain(in: bounds, context: &context)
        }
        .accessibilityHidden(true)
    }

    /// Draws a very faint, fibrous grain texture across the canvas.
    /// Uses a fixed-seed LCG to generate deterministic positions and sizes.
    private func drawGrain(in bounds: CGRect, context: inout GraphicsContext) {
        let grainCount = 320 // Enough speckles to read as texture, not decoration.
        let grainOpacity = 0.035 // Very low—barely visible, texture not decoration.
        var rng = SimpleRNG(seed: seed)

        for _ in 0 ..< grainCount {
            let x = CGFloat(rng.next()) * bounds.width
            let y = CGFloat(rng.next()) * bounds.height
            let size = CGFloat(rng.nextRange(min: 0.5, max: 2.0))

            let path = Path(ellipseIn: CGRect(x: x, y: y, width: size, height: size))

            context.fill(
                path,
                with: .color(Theme.ink.opacity(grainOpacity))
            )
        }
    }
}

/// A simple fixed-seed LCG (Linear Congruential Generator) for deterministic
/// pseudo-random grain placement. Seeded with a constant, so the same pattern
/// draws every render.
private struct SimpleRNG {
    private var state: UInt32

    init(seed: UInt32) {
        self.state = seed
    }

    /// Returns a pseudo-random value in the range [0.0, 1.0).
    mutating func next() -> Double {
        // Standard LCG parameters: a = 1103515245, c = 12345, m = 2^31
        state = state &* 1103515245 &+ 12345
        return Double(state & 0x7FFFFFFF) / 2147483647.0
    }

    /// Returns a pseudo-random value in the range [min, max).
    mutating func nextRange(min: Double, max: Double) -> Double {
        min + next() * (max - min)
    }
}

// MARK: - Preview

#Preview("PaperGround with Text") {
    ZStack {
        PaperGround()

        VStack(spacing: 16) {
            Text("Field Journal")
                .font(.system(size: 32, weight: .bold, design: .default))
                .foregroundColor(Theme.ink)

            Text("The grain beneath this text is barely visible—texture, not decoration. It shifts to match light and dark automatically.")
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(nil)

            Spacer()
        }
        .padding(24)
    }
    .ignoresSafeArea()
}
