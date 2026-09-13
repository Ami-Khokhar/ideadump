import SwiftUI

/// Hand-drawn climbing vines, generated rather than authored.
///
/// The first attempt at this drew a near-straight spine and hung leaves along it
/// at even intervals, strictly alternating sides. That reads as a bottle brush,
/// not a plant, and adding more leaves only made the regularity louder. What
/// makes foliage look grown is irregularity of a particular kind:
///
/// - the spine meanders with a varying amplitude *and* a varying step, so no
///   single wavelength shows through;
/// - leaves arrive in clusters separated by bare stretches, never on a grid;
/// - which side a leaf takes is random, not alternating, and the angle spread
///   is wide;
/// - leaves shrink toward the growing tip;
/// - every leaf hangs off a short stalk, so it attaches instead of floating.
///
/// Everything here is seeded from an explicit integer. Nothing uses `hashValue`
/// (randomised per launch) or `Double.random`, because a vine that reshuffles
/// between redraws reads as a rendering bug rather than as decoration.
enum VineArt {

    /// One drawable piece of a vine, in the same shape `TreeArt` uses so both
    /// can be painted through a `GraphicsContext` the same way.
    struct Part {
        let path: Path
        let transform: CGAffineTransform
        let opacity: Double
        /// Zero fills; anything larger strokes at that width.
        let lineWidth: CGFloat
        /// Position along the plant, 0 at the root and 1 at the tip. The opening
        /// animation reveals parts in this order so growth climbs the stem.
        let growth: Double
    }

    // MARK: - Deterministic noise

    /// A small LCG. Explicitly seeded so a given vine is identical on every
    /// launch, every redraw and every device.
    struct Generator {
        private var state: UInt64

        init(seed: UInt64) {
            // Spread small seeds across the state space; consecutive seeds
            // otherwise produce visibly similar first values.
            state = (seed &* 2_654_435_761) % 2_147_483_648
        }

        mutating func next() -> Double {
            state = (state &* 1_103_515_245 &+ 12_345) & 0x7FFF_FFFF
            return Double(state) / Double(0x7FFF_FFFF)
        }

        mutating func range(_ lower: Double, _ upper: Double) -> Double {
            lower + (upper - lower) * next()
        }
    }

    // MARK: - Spine

    /// A meandering climb from `y0` up to `y1`.
    ///
    /// `wander` is the side-to-side reach and `lean` the total drift by the time
    /// it reaches the top. Both the step height and the wander amplitude are
    /// re-rolled every step: holding either one constant is what made the first
    /// version look like a wire.
    static func spine(
        seed: UInt64,
        x0: CGFloat,
        y0: CGFloat,
        y1: CGFloat,
        lean: CGFloat,
        wander: CGFloat
    ) -> (points: [CGPoint], generator: Generator) {
        var rng = Generator(seed: seed)
        var points = [CGPoint(x: x0, y: y0)]
        var y = y0
        var phase = rng.range(0, 6.3)
        let span = max(y0 - y1, 1)

        while y > y1 {
            y -= CGFloat(rng.range(26, 46))
            phase += rng.range(0.5, 1.15)
            let amplitude = wander * CGFloat(rng.range(0.45, 1.35))
            let progress = (y0 - y) / span
            let x = x0 + CGFloat(sin(phase)) * amplitude + lean * progress
            points.append(CGPoint(x: x, y: y))
        }
        return (points, rng)
    }

    /// A smooth curve through `points`, Catmull-Rom converted to cubic segments.
    static func smoothPath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 1 else { return path }

        for i in 0..<(points.count - 1) {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(i + 2, points.count - 1)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }

    /// Point and tangent at `t` along the polyline. Sampling the polyline rather
    /// than the smoothed curve is close enough at this leaf density and keeps
    /// the placement cheap.
    private static func sample(_ points: [CGPoint], _ t: Double) -> (point: CGPoint, tangent: CGVector) {
        guard points.count > 1 else {
            return (points.first ?? .zero, CGVector(dx: 0, dy: -1))
        }
        let n = points.count - 1
        let scaled = min(max(t, 0), 0.999) * Double(n)
        let index = min(Int(scaled), n - 1)
        let local = CGFloat(scaled - Double(index))
        let a = points[index], b = points[index + 1]
        return (
            CGPoint(x: a.x + (b.x - a.x) * local, y: a.y + (b.y - a.y) * local),
            CGVector(dx: b.x - a.x, dy: b.y - a.y)
        )
    }

    // MARK: - Leaves

    /// Three leaf outlines on a shared baseline: tip at +x, hinge at the origin,
    /// each about 11 units long. Three rather than one so a cluster does not
    /// read as the same stamp repeated.
    private static let leafShapes: [Path] = [
        {
            var p = Path()
            p.move(to: .zero)
            p.addCurve(to: CGPoint(x: 11.5, y: 0), control1: CGPoint(x: 2.4, y: -3.4), control2: CGPoint(x: 7.6, y: -3.6))
            p.addCurve(to: .zero, control1: CGPoint(x: 7.6, y: 2.9), control2: CGPoint(x: 2.4, y: 2.4))
            p.closeSubpath()
            return p
        }(),
        {
            var p = Path()
            p.move(to: .zero)
            p.addCurve(to: CGPoint(x: 10.6, y: 0.4), control1: CGPoint(x: 3.1, y: -2.6), control2: CGPoint(x: 8.4, y: -2.2))
            p.addCurve(to: .zero, control1: CGPoint(x: 7.4, y: 3.4), control2: CGPoint(x: 2.2, y: 2.2))
            p.closeSubpath()
            return p
        }(),
        {
            var p = Path()
            p.move(to: .zero)
            p.addCurve(to: CGPoint(x: 10.2, y: -1.2), control1: CGPoint(x: 1.9, y: -3.9), control2: CGPoint(x: 6.8, y: -4.4))
            p.addCurve(to: .zero, control1: CGPoint(x: 7.8, y: 2.2), control2: CGPoint(x: 2.6, y: 2.6))
            p.closeSubpath()
            return p
        }()
    ]

    /// Leaves in clusters along `points`, each on its own stalk.
    ///
    /// `inwardLimit` is the x the foliage is growing beside. A leaf pointing back
    /// toward it is kept but drawn short, which is what stops the margin vines
    /// creeping over the amount and the category tiles. Pass nil for a free-
    /// standing plant that may grow in every direction.
    static func foliage(
        along points: [CGPoint],
        rng: inout Generator,
        clusters: Int,
        baseScale: CGFloat,
        tipScale: CGFloat,
        inwardLimit: CGFloat?
    ) -> [Part] {
        var parts: [Part] = []

        for cluster in 0..<clusters {
            let anchor = (Double(cluster) + rng.range(0.15, 0.85)) / Double(clusters)
            let count = Int(rng.range(3, 7.99))

            for _ in 0..<count {
                let t = min(max(anchor + rng.range(-0.022, 0.022), 0.01), 0.99)
                let (point, tangent) = sample(points, t)
                let tangentAngle = atan2(tangent.dy, tangent.dx)
                let side: CGFloat = rng.next() < 0.5 ? 1 : -1
                let angle = tangentAngle + side * CGFloat(rng.range(38, 96)) * .pi / 180

                let taper = baseScale + (tipScale - baseScale) * CGFloat(t)
                var scale = taper * CGFloat(rng.range(0.62, 1.3))

                if let limit = inwardLimit {
                    let pointsInward = (point.x < limit && cos(angle) > 0)
                        || (point.x > limit && cos(angle) < 0)
                    if pointsInward { scale *= 0.62 }
                }

                let opacity = rng.range(0.30, 0.62)
                let stalkLength = CGFloat(rng.range(2.5, 5.5)) * taper
                let hinge = CGPoint(
                    x: point.x + cos(angle) * stalkLength,
                    y: point.y + sin(angle) * stalkLength
                )

                var stalk = Path()
                stalk.move(to: point)
                stalk.addLine(to: hinge)
                parts.append(Part(path: stalk, transform: .identity,
                                  opacity: opacity * 0.9, lineWidth: 1.1, growth: t))

                let shape = leafShapes[Int(rng.next() * Double(leafShapes.count)) % leafShapes.count]
                let transform = CGAffineTransform(translationX: hinge.x, y: hinge.y)
                    .rotated(by: angle)
                    .scaledBy(x: scale, y: scale)
                parts.append(Part(path: shape, transform: transform,
                                  opacity: opacity, lineWidth: 0, growth: t))
            }
        }
        return parts
    }

    /// Curling tendrils. More than any leaf, these are what read as "vine".
    static func tendrils(
        along points: [CGPoint],
        rng: inout Generator,
        count: Int
    ) -> [Part] {
        var parts: [Part] = []

        for i in 0..<count {
            let t = rng.range(0.15, 0.9)
            let (point, tangent) = sample(points, t)
            let side: CGFloat = rng.next() < 0.5 ? 1 : -1
            var theta = atan2(tangent.dy, tangent.dx) + side * CGFloat(rng.range(55, 95)) * .pi / 180

            var path = Path()
            path.move(to: point)
            var cursor = point
            var radius = CGFloat(rng.range(7, 13))
            let spin: CGFloat = i % 2 == 0 ? -1 : 1

            for _ in 0..<4 {
                theta += spin * CGFloat(rng.range(1.1, 1.7))
                radius *= 0.68
                let next = CGPoint(x: cursor.x + cos(theta) * radius, y: cursor.y + sin(theta) * radius)
                let control = CGPoint(
                    x: cursor.x + cos(theta - 0.6) * radius * 1.5,
                    y: cursor.y + sin(theta - 0.6) * radius * 1.5
                )
                path.addQuadCurve(to: next, control: control)
                cursor = next
            }
            parts.append(Part(path: path, transform: .identity,
                              opacity: rng.range(0.35, 0.6), lineWidth: 1.2, growth: t))
        }
        return parts
    }

    // MARK: - Compositions

    /// Design canvas the compositions below are authored against. Both are
    /// scaled to whatever frame they are drawn into.
    static let canvas = CGSize(width: 402, height: 874)

    /// Where the capture screen's vines root, in canvas units. Just above the
    /// category line, which sits at roughly 364.
    static let bandBottom: CGFloat = 358

    /// The band over which `VineBorder` fades the vines out, as fractions of
    /// screen height. Ends above the category line so nothing reaches the line
    /// or the tiles under it. Cluster counts above are chosen against this
    /// shorter band, so the foliage stays as dense per unit of stem as the
    /// design it was tuned from.
    static let fadeStart: CGFloat = 0.345
    static let fadeEnd: CGFloat = 0.415

    /// The capture screen's margin vines: one climbing each edge, plus a shorter
    /// shoot at each base so it reads as a plant rather than a single wire.
    ///
    /// Bounded to the outer margins on purpose. The grove that used to sit on
    /// this screen was removed for crowding the amount, and this only earns its
    /// place by staying out of the way. `inwardLimit` is the screen midline:
    /// leaves that would reach across it are drawn short.
    ///
    /// The vines also stop short vertically, at `bandBottom`, which sits just
    /// above the category line. They used to root at 452 — level with the
    /// category tiles — and a vine is widest at its base, so the densest
    /// foliage landed straight on the first and last tile and clipped the "C"
    /// off "Chai". The tile row runs nearly edge to edge, so there is no margin
    /// left to squeeze into at that height: the only way for the vines not to
    /// cover the tiles is to end before them. `VineBorder` fades the last of
    /// the band out, so the plants recede into the paper rather than stopping
    /// on a line.
    static func captureMargins() -> [Part] {
        var parts: [Part] = []
        let midline: CGFloat = canvas.width / 2

        func climb(
            seed: UInt64, x0: CGFloat, y0: CGFloat, y1: CGFloat,
            lean: CGFloat, wander: CGFloat,
            opacity: Double, lineWidth: CGFloat,
            tendrilCount: Int, clusters: Int, baseScale: CGFloat, tipScale: CGFloat
        ) {
            let stem = spine(seed: seed, x0: x0, y0: y0, y1: y1, lean: lean, wander: wander)
            var rng = stem.generator
            parts.append(Part(path: smoothPath(stem.points), transform: .identity,
                              opacity: opacity, lineWidth: lineWidth, growth: 0))
            if tendrilCount > 0 {
                parts += tendrils(along: stem.points, rng: &rng, count: tendrilCount)
            }
            parts += foliage(along: stem.points, rng: &rng, clusters: clusters,
                             baseScale: baseScale, tipScale: tipScale, inwardLimit: midline)
        }

        climb(seed: 3, x0: 16, y0: bandBottom, y1: 84, lean: 9, wander: 13,
              opacity: 0.62, lineWidth: 2.4, tendrilCount: 3,
              clusters: 18, baseScale: 2.35, tipScale: 0.95)
        climb(seed: 17, x0: 387, y0: bandBottom - 6, y1: 112, lean: -10, wander: 13,
              opacity: 0.58, lineWidth: 2.2, tendrilCount: 3,
              clusters: 16, baseScale: 2.25, tipScale: 0.92)
        // Second, shorter shoot off each base. One stem alone reads as a wire
        // however many leaves it carries; two of different heights read as one
        // plant.
        climb(seed: 12, x0: 34, y0: bandBottom - 2, y1: 232, lean: 8, wander: 9,
              opacity: 0.42, lineWidth: 1.6, tendrilCount: 0,
              clusters: 7, baseScale: 1.6, tipScale: 0.78)
        climb(seed: 22, x0: 370, y0: bandBottom - 8, y1: 244, lean: -8, wander: 9,
              opacity: 0.40, lineWidth: 1.5, tendrilCount: 0,
              clusters: 6, baseScale: 1.55, tipScale: 0.75)

        return parts
    }

    /// The opening plant: two shoots from a single seed, leaning apart as they
    /// climb. Same generator as the margins, so the launch screen and the
    /// capture screen are visibly the same species.
    struct Sprout {
        /// The two stems, kept apart from the rest so the opening can trim them
        /// and draw them as strokes in progress.
        let stems: [Part]
        /// Tendrils and foliage, revealed in `growth` order behind the stroke.
        let details: [Part]
        let seed: CGPoint
        let ground: Path
    }

    static func sprout() -> Sprout {
        var stems: [Part] = []
        var details: [Part] = []

        func shoot(
            seed: UInt64, lean: CGFloat, wander: CGFloat, y1: CGFloat,
            opacity: Double, lineWidth: CGFloat,
            clusters: Int, baseScale: CGFloat, tipScale: CGFloat
        ) {
            let stem = spine(seed: seed, x0: 208, y0: 618, y1: y1, lean: lean, wander: wander)
            var rng = stem.generator
            stems.append(Part(path: smoothPath(stem.points), transform: .identity,
                              opacity: opacity, lineWidth: lineWidth, growth: 0))
            details += tendrils(along: stem.points, rng: &rng, count: 3)
            // No inward limit: this plant stands alone in the middle of the
            // screen, so it is free to grow in every direction.
            details += foliage(along: stem.points, rng: &rng, clusters: clusters,
                               baseScale: baseScale, tipScale: tipScale, inwardLimit: nil)
        }

        shoot(seed: 3, lean: -48, wander: 16, y1: 236,
              opacity: 0.62, lineWidth: 2.3, clusters: 22, baseScale: 2.8, tipScale: 1.15)
        shoot(seed: 21, lean: 58, wander: 17, y1: 262,
              opacity: 0.58, lineWidth: 2.1, clusters: 21, baseScale: 2.7, tipScale: 1.1)

        var ground = Path()
        ground.move(to: CGPoint(x: 157, y: 624))
        ground.addLine(to: CGPoint(x: 259, y: 624))

        return Sprout(stems: stems, details: details,
                      seed: CGPoint(x: 208, y: 618), ground: ground)
    }
}

extension GraphicsContext {
    /// The transform that maps the vine design canvas onto `size`.
    ///
    /// Fills rather than fits: these are decorations pinned to the screen edges,
    /// so letterboxing them would pull the vines off the edge they hug.
    static func vineFit(canvas: CGSize, in size: CGSize) -> CGAffineTransform {
        let scale = max(size.width / canvas.width, size.height / canvas.height)
        return CGAffineTransform(
            translationX: (size.width - canvas.width * scale) / 2,
            y: (size.height - canvas.height * scale) / 2
        ).scaledBy(x: scale, y: scale)
    }

    /// Draws vine `parts` authored on `canvas`, scaled to fill `size`.
    ///
    /// `revealedThrough` is a position along the plant: parts past it are not
    /// drawn, and parts within `fadeBand` behind it are drawn part-way in. That
    /// is what makes the opening's foliage unfurl base-to-tip behind the stroke.
    /// The default draws everything at full strength.
    func drawVines(
        _ parts: [VineArt.Part],
        canvas: CGSize,
        in size: CGSize,
        color: Color,
        revealedThrough: Double = 1,
        fadeBand: Double = 0,
        trim: Double = 1
    ) {
        let fit = GraphicsContext.vineFit(canvas: canvas, in: size)
        let scale = max(size.width / canvas.width, size.height / canvas.height)

        for part in parts {
            var alpha = part.opacity
            if fadeBand > 0 {
                let entered = (revealedThrough - part.growth) / fadeBand
                guard entered > 0 else { continue }
                alpha *= min(entered, 1)
            } else if part.growth > revealedThrough {
                continue
            }

            var path = part.path
            if trim < 1 { path = path.trimmedPath(from: 0, to: CGFloat(max(trim, 0))) }
            let resolved = path.applying(part.transform.concatenating(fit))
            let shading = Shading.color(color.opacity(alpha))
            if part.lineWidth > 0 {
                stroke(resolved, with: shading,
                       style: StrokeStyle(lineWidth: part.lineWidth * scale,
                                          lineCap: .round, lineJoin: .round))
            } else {
                fill(resolved, with: shading)
            }
        }
    }
}
