import SwiftUI

/// Renders a small grove scene: several budget trees arranged on a ground line,
/// layered by depth using painter's algorithm.
///
/// The view composites trees at varied depth and maturity in a single Canvas,
/// creating a botanical tableau that decorates the capture interface. Trees are
/// sorted back-to-front by depth so near, larger trees overplot distant ones.
/// Bloom indicators add sparse color to trees in recovery or growth states.
///
/// Accessibility: the Canvas itself is hidden and replaced with a spoken summary
/// describing grove health at a glance, so VoiceOver reads meaning instead of
/// individual tree geometry.
struct GroveScene: View {
    /// Layout and state for each plant.
    let plants: [GrovePlant]

    /// Renders the grove and its accessibility label.
    var body: some View {
        ZStack(alignment: .center) {
            // The Canvas is hidden from VoiceOver; the summary label floats above it.
            Canvas(opaque: false) { context, size in
                drawGround(in: context, size: size)
                drawTrees(in: context, size: size)
            }
            .accessibilityHidden(true)
        }
        .accessibilityElement()
        .accessibilityLabel(GroveSceneModel.summary(for: plants))
    }

    // MARK: - Drawing

    /// Draws a soft ground line near the bottom of the canvas.
    private func drawGround(in context: GraphicsContext, size: CGSize) {
        let baselineY = size.height * 0.9
        var path = Path()
        path.move(to: CGPoint(x: 0, y: baselineY))
        path.addLine(to: CGPoint(x: size.width, y: baselineY))

        let shading = GraphicsContext.Shading.color(Theme.bark.opacity(0.25))
        context.stroke(
            path,
            with: shading,
            style: StrokeStyle(lineWidth: 1, lineCap: .round)
        )
    }

    /// Draws each tree sorted by depth, so far trees render first and near trees
    /// overplot them. Per-tree sizing interpolates depth and maturity to scale trees
    /// from ~40% to ~100% of canvas height.
    private func drawTrees(in context: GraphicsContext, size: CGSize) {
        let baselineY = size.height * 0.9

        // Sort by depth ascending so far trees (depth ~0) draw first.
        let sortedPlants = plants.sorted { $0.depth < $1.depth }

        for plant in sortedPlants {
            // Compute tree height: interpolate from 40% to 100% of canvas height
            // using both depth (0=far/small, 1=near/large) and height (maturity).
            let minDrawHeight = size.height * 0.4
            let maxDrawHeight = size.height * 1.0
            let depthScale = plant.depth  // 0...1, 0=far, 1=near
            let maturityScale = plant.height  // 0...1, 0=seedling, 1=mature
            let blendedScale = depthScale * 0.5 + maturityScale * 0.5
            let treeDrawHeight = minDrawHeight + (maxDrawHeight - minDrawHeight) * blendedScale

            // Width preserves the 64×80 canvas aspect ratio.
            let canvasAspect = TreeArt.canvas.width / TreeArt.canvas.height  // 64/80 = 0.8
            var treeWidth = treeDrawHeight * canvasAspect

            // Species subtly influences width: columnar=narrower, spreading=wider.
            let speciesWidthFactor: CGFloat
            switch plant.species {
            case .rounded:
                speciesWidthFactor = 1.0
            case .columnar:
                speciesWidthFactor = 0.9
            case .spreading:
                speciesWidthFactor = 1.1
            }
            treeWidth *= speciesWidthFactor

            // Center the tree horizontally using normalizedX, clamped to screen bounds.
            let treeX = plant.normalizedX * size.width
            let clampedX = max(treeWidth / 2, min(size.width - treeWidth / 2, treeX))

            // Construct the tree rect: centered at (clampedX, baselineY), bottom edge on baseline.
            let treeRect = CGRect(
                x: clampedX - treeWidth / 2,
                y: baselineY - treeDrawHeight,
                width: treeWidth,
                height: treeDrawHeight
            )

            // Draw the tree by translating context and applying drawTree.
            var subContext = context
            subContext.translateBy(x: treeRect.minX, y: treeRect.minY)
            subContext.drawTree(
                TreeArt.parts(for: plant.health),
                canvas: TreeArt.canvas,
                in: treeRect.size,
                color: plant.tint
            )

            // Draw bloom indicators if the plant is flowering or budding.
            drawBloom(
                in: context,
                treeRect: treeRect,
                treeDrawHeight: treeDrawHeight,
                bloom: plant.bloom,
                categoryKey: plant.categoryKey,
                tint: plant.tint
            )
        }
    }

    /// Draws sparse bloom indicators (2–3 dots for flowering, 1 dot for budding)
    /// near the crown of the tree.
    private func drawBloom(
        in context: GraphicsContext,
        treeRect: CGRect,
        treeDrawHeight: CGFloat,
        bloom: BloomState,
        categoryKey: String,
        tint: Color
    ) {
        guard bloom != .none else { return }

        let dotCount: Int
        let bloomColor: Color

        switch bloom {
        case .flowering:
            dotCount = 3
            // Alternate marigold and rose deterministically per category. A byte
            // sum is stable across launches, unlike `hashValue`, so a category's
            // flower colour never changes between renders.
            let colorHash = categoryKey.utf8.reduce(0) { $0 &+ Int($1) }
            bloomColor = colorHash % 2 == 0 ? Theme.bloomMarigold : Theme.bloomRose
        case .budding:
            dotCount = 1
            bloomColor = Theme.bloomMarigold
        case .none:
            return
        }

        // Scale dot radius to tree size.
        let dotRadius = max(1.5, treeDrawHeight * 0.035)

        // Crown is the top ~30% of the tree.
        let crownTop = treeRect.minY + treeDrawHeight * 0.15
        let crownBottom = treeRect.minY + treeDrawHeight * 0.35
        let crownCenterX = treeRect.midX

        // Place dots deterministically along the crown, spread horizontally. The
        // vertical offset is seeded from the key and the dot index, so the bloom
        // sits in the same place every render rather than jittering.
        for i in 0..<dotCount {
            let horizontalSpread = CGFloat(i) - CGFloat(dotCount - 1) / 2.0
            let dotX = crownCenterX + horizontalSpread * dotRadius * 2.5
            let seed = categoryKey.utf8.reduce(UInt64(i &+ 1)) { ($0 &* 31) &+ UInt64($1) }
            let frac = CGFloat(seed % 1000) / 1000.0
            let dotY = crownTop + frac * (crownBottom - crownTop)

            let path = Path(ellipseIn: CGRect(
                x: dotX - dotRadius,
                y: dotY - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            ))

            context.fill(path, with: .color(bloomColor))
        }
    }
}

#Preview("Grove Scene") {
    // Build a few sample plants with varied health, depth, normalizedX, species, and bloom.
    let plants = [
        GrovePlant(
            categoryKey: "groceries",
            species: .rounded,
            health: .growing,
            normalizedX: 0.2,
            depth: 0.3,
            height: 0.8,
            tint: Theme.moss,
            bloom: .flowering,
            accessibilitySummary: "Groceries: growing"
        ),
        GrovePlant(
            categoryKey: "gas",
            species: .columnar,
            health: .sprout,
            normalizedX: 0.5,
            depth: 0.6,
            height: 0.5,
            tint: Theme.moss,
            bloom: .budding,
            accessibilitySummary: "Gas: sprout"
        ),
        GrovePlant(
            categoryKey: "dining",
            species: .spreading,
            health: .wilting,
            normalizedX: 0.8,
            depth: 0.2,
            height: 0.6,
            tint: Theme.clay,
            bloom: .none,
            accessibilitySummary: "Dining: wilting"
        ),
        GrovePlant(
            categoryKey: "entertainment",
            species: .rounded,
            health: .seedling,
            normalizedX: 0.35,
            depth: 0.5,
            height: 0.3,
            tint: Theme.moss,
            bloom: .none,
            accessibilitySummary: "Entertainment: seedling"
        ),
        GrovePlant(
            categoryKey: "transit",
            species: .columnar,
            health: .resting,
            normalizedX: 0.7,
            depth: 0.8,
            height: 0.7,
            tint: Theme.clay,
            bloom: .none,
            accessibilitySummary: "Transit: resting"
        ),
    ]

    return ZStack {
        Theme.paper
            .ignoresSafeArea()

        VStack {
            Text("Grove Scene Preview")
                .font(.headline)
                .foregroundColor(Theme.ink)
                .padding()

            GroveScene(plants: plants)
                .frame(height: 140)
                .padding()
                .background(Theme.paper)
        }
    }
}
