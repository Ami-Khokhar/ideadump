import SwiftUI

/// Illustrated tree marks for the six `BudgetCalculator.TreeHealth` states.
///
/// The geometry is generated from the design canvas artwork — do not hand-edit
/// the coordinates in `Geometry`. Every mark is authored on a 64×80 grid and
/// scaled to fit whatever frame the view is given.
///
/// Crowns are built from many copies of one leaf-mass at partial opacity: where
/// the copies overlap, the alpha compounds and darkens on its own, so the canopy
/// gets its depth from compositing rather than from separate light and dark
/// shapes. That is why every part carries its own `opacity`.
enum TreeArt {

    /// Design-time canvas the coordinates are authored against.
    static let canvas = CGSize(width: 64, height: 80)

    struct TreePart {
        let path: Path
        let transform: CGAffineTransform
        let opacity: Double
        /// Zero means fill; anything larger strokes at that width.
        let lineWidth: CGFloat
    }

    private enum Geometry {
        /// Soft shadow the tree stands on.
        static let ground = Path(ellipseIn: CGRect(x: 19.5, y: 70.3, width: 25, height: 5))

    static let g0: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -4.2))
        p.addCurve(to: CGPoint(x: 2.1, y: 3.4), control1: CGPoint(x: 2.7, y: -2.7), control2: CGPoint(x: 3.6, y: 0.6))
        p.addCurve(to: CGPoint(x: -2.1, y: 3.4), control1: CGPoint(x: 0.6, y: 5.2), control2: CGPoint(x: -0.6, y: 5.2))
        p.addCurve(to: CGPoint(x: 0, y: -4.2), control1: CGPoint(x: -3.6, y: 0.6), control2: CGPoint(x: -2.7, y: -2.7))
        p.closeSubpath()
        return p
    }()

    static let g1: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 30.6, y: 64.4))
        p.addCurve(to: CGPoint(x: 33.8, y: 64.2), control1: CGPoint(x: 31.6, y: 63.2), control2: CGPoint(x: 32.8, y: 63.2))
        return p
    }()

    static let g2: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 30.2, y: 72.5))
        p.addCurve(to: CGPoint(x: 31.5, y: 53.5), control1: CGPoint(x: 30.9, y: 66), control2: CGPoint(x: 31.2, y: 60))
        p.addLine(to: CGPoint(x: 33, y: 53.5))
        p.addCurve(to: CGPoint(x: 34.3, y: 72.5), control1: CGPoint(x: 33.2, y: 60), control2: CGPoint(x: 33.6, y: 66))
        p.closeSubpath()
        return p
    }()

    static let g3: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 31.4, y: 57))
        p.addCurve(to: CGPoint(x: 18.2, y: 49.2), control1: CGPoint(x: 26.2, y: 57.8), control2: CGPoint(x: 20.6, y: 55))
        p.addCurve(to: CGPoint(x: 31.4, y: 53.6), control1: CGPoint(x: 24.2, y: 46.4), control2: CGPoint(x: 29.4, y: 48.8))
        p.closeSubpath()
        return p
    }()

    static let g4: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 31.4, y: 56.6))
        p.addCurve(to: CGPoint(x: 20.4, y: 50.2), control1: CGPoint(x: 27.6, y: 54.6), control2: CGPoint(x: 24, y: 52.4))
        return p
    }()

    static let g5: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 32.7, y: 54.4))
        p.addCurve(to: CGPoint(x: 45.9, y: 46.6), control1: CGPoint(x: 37.9, y: 55.2), control2: CGPoint(x: 43.5, y: 52.4))
        p.addCurve(to: CGPoint(x: 32.7, y: 51), control1: CGPoint(x: 39.9, y: 43.8), control2: CGPoint(x: 34.7, y: 46.2))
        p.closeSubpath()
        return p
    }()

    static let g6: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 32.7, y: 54))
        p.addCurve(to: CGPoint(x: 43.7, y: 47.6), control1: CGPoint(x: 36.5, y: 52), control2: CGPoint(x: 40.1, y: 49.8))
        return p
    }()

    static let g7: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 32.2, y: 47.6))
        p.addCurve(to: CGPoint(x: 32.3, y: 55), control1: CGPoint(x: 34.1, y: 49.9), control2: CGPoint(x: 34.2, y: 52.6))
        p.addCurve(to: CGPoint(x: 32.2, y: 47.6), control1: CGPoint(x: 30.4, y: 52.7), control2: CGPoint(x: 30.3, y: 50))
        p.closeSubpath()
        return p
    }()

    static let g8: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 29.8, y: 72.5))
        p.addCurve(to: CGPoint(x: 31.5, y: 38.5), control1: CGPoint(x: 30.7, y: 63), control2: CGPoint(x: 31.2, y: 51))
        p.addLine(to: CGPoint(x: 33.1, y: 38.5))
        p.addCurve(to: CGPoint(x: 34.8, y: 72.5), control1: CGPoint(x: 33.4, y: 51), control2: CGPoint(x: 33.9, y: 63))
        p.closeSubpath()
        return p
    }()

    static let g9: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 31.3, y: 60.5))
        p.addCurve(to: CGPoint(x: 15.6, y: 51.6), control1: CGPoint(x: 25.2, y: 61.6), control2: CGPoint(x: 18.4, y: 58.4))
        p.addCurve(to: CGPoint(x: 31.3, y: 56.8), control1: CGPoint(x: 22.6, y: 48.2), control2: CGPoint(x: 28.8, y: 51.2))
        p.closeSubpath()
        return p
    }()

    static let g10: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 31.3, y: 60))
        p.addCurve(to: CGPoint(x: 18, y: 52.4), control1: CGPoint(x: 26.6, y: 57.6), control2: CGPoint(x: 22.2, y: 55))
        return p
    }()

    static let g11: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 32.9, y: 57.5))
        p.addCurve(to: CGPoint(x: 48.6, y: 48.6), control1: CGPoint(x: 39, y: 58.6), control2: CGPoint(x: 45.8, y: 55.4))
        p.addCurve(to: CGPoint(x: 32.9, y: 53.8), control1: CGPoint(x: 41.6, y: 45.2), control2: CGPoint(x: 35.4, y: 48.2))
        p.closeSubpath()
        return p
    }()

    static let g12: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 32.9, y: 57))
        p.addCurve(to: CGPoint(x: 46.2, y: 49.4), control1: CGPoint(x: 37.6, y: 54.6), control2: CGPoint(x: 42, y: 52))
        return p
    }()

    static let g13: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 31.4, y: 48.5))
        p.addCurve(to: CGPoint(x: 19.2, y: 41.4), control1: CGPoint(x: 26.6, y: 49.2), control2: CGPoint(x: 21.4, y: 46.7))
        p.addCurve(to: CGPoint(x: 31.4, y: 45.5), control1: CGPoint(x: 24.6, y: 38.8), control2: CGPoint(x: 29.4, y: 41.1))
        p.closeSubpath()
        return p
    }()

    static let g14: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 31.4, y: 48))
        p.addCurve(to: CGPoint(x: 21.2, y: 41.9), control1: CGPoint(x: 27.7, y: 46), control2: CGPoint(x: 24.2, y: 43.8))
        return p
    }()

    static let g15: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 33, y: 45.5))
        p.addCurve(to: CGPoint(x: 45.2, y: 38.4), control1: CGPoint(x: 37.8, y: 46.2), control2: CGPoint(x: 43, y: 43.7))
        p.addCurve(to: CGPoint(x: 33, y: 42.5), control1: CGPoint(x: 39.8, y: 35.8), control2: CGPoint(x: 35, y: 38.1))
        p.closeSubpath()
        return p
    }()

    static let g16: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 33, y: 45))
        p.addCurve(to: CGPoint(x: 43.2, y: 38.9), control1: CGPoint(x: 36.7, y: 43), control2: CGPoint(x: 40.2, y: 40.8))
        return p
    }()

    static let g17: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 32.3, y: 30.5))
        p.addCurve(to: CGPoint(x: 32.4, y: 42.6), control1: CGPoint(x: 35.4, y: 34.2), control2: CGPoint(x: 35.6, y: 38.9))
        p.addCurve(to: CGPoint(x: 32.3, y: 30.5), control1: CGPoint(x: 29.2, y: 38.9), control2: CGPoint(x: 29.2, y: 34.2))
        p.closeSubpath()
        return p
    }()

    static let g18: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 32.3, y: 32.5))
        p.addCurve(to: CGPoint(x: 32.4, y: 41.6), control1: CGPoint(x: 32.3, y: 36), control2: CGPoint(x: 32.3, y: 39))
        return p
    }()

    static let g19: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 25.2, y: 72.5))
        p.addCurve(to: CGPoint(x: 29.1, y: 61.4), control1: CGPoint(x: 27.4, y: 68.6), control2: CGPoint(x: 28.4, y: 65.4))
        p.addCurve(to: CGPoint(x: 30.6, y: 43.2), control1: CGPoint(x: 30, y: 55.2), control2: CGPoint(x: 30.3, y: 49.6))
        p.addLine(to: CGPoint(x: 33.6, y: 43.2))
        p.addCurve(to: CGPoint(x: 35.3, y: 61.4), control1: CGPoint(x: 33.9, y: 49.6), control2: CGPoint(x: 34.4, y: 55.2))
        p.addCurve(to: CGPoint(x: 39.2, y: 72.5), control1: CGPoint(x: 36, y: 65.4), control2: CGPoint(x: 37, y: 68.6))
        p.closeSubpath()
        return p
    }()

    static let g20: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 30.7, y: 55.5))
        p.addCurve(to: CGPoint(x: 20.6, y: 45.6), control1: CGPoint(x: 27, y: 52.4), control2: CGPoint(x: 23.4, y: 49))
        return p
    }()

    static let g21: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 33.5, y: 50.5))
        p.addCurve(to: CGPoint(x: 44, y: 43.6), control1: CGPoint(x: 37, y: 47.8), control2: CGPoint(x: 40.6, y: 45.4))
        return p
    }()

    static let g22: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 30.8, y: 46))
        p.addCurve(to: CGPoint(x: 26.4, y: 37.8), control1: CGPoint(x: 29, y: 43), control2: CGPoint(x: 27.6, y: 40.6))
        return p
    }()

    static let g23: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -10.4))
        p.addCurve(to: CGPoint(x: 9.9, y: -3.4), control1: CGPoint(x: 4.6, y: -10.6), control2: CGPoint(x: 8.8, y: -7.6))
        p.addCurve(to: CGPoint(x: 5.4, y: 7.8), control1: CGPoint(x: 11, y: 0.8), control2: CGPoint(x: 9.2, y: 5.4))
        p.addCurve(to: CGPoint(x: -6.4, y: 7), control1: CGPoint(x: 1.8, y: 10.1), control2: CGPoint(x: -3.2, y: 9.8))
        p.addCurve(to: CGPoint(x: -9.2, y: -4.4), control1: CGPoint(x: -9.6, y: 4.2), control2: CGPoint(x: -10.8, y: -0.4))
        p.addCurve(to: CGPoint(x: 0, y: -10.4), control1: CGPoint(x: -7.7, y: -8.2), control2: CGPoint(x: -4.2, y: -10.3))
        p.closeSubpath()
        return p
    }()

    static let g24: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 25.6, y: 72.5))
        p.addCurve(to: CGPoint(x: 29.5, y: 61.6), control1: CGPoint(x: 27.8, y: 68.8), control2: CGPoint(x: 28.8, y: 65.6))
        p.addCurve(to: CGPoint(x: 32.2, y: 46.4), control1: CGPoint(x: 30.4, y: 56), control2: CGPoint(x: 31.2, y: 51.6))
        p.addLine(to: CGPoint(x: 35, y: 46.8))
        p.addCurve(to: CGPoint(x: 35.2, y: 61.6), control1: CGPoint(x: 34.3, y: 51.9), control2: CGPoint(x: 34.6, y: 56.2))
        p.addCurve(to: CGPoint(x: 39, y: 72.5), control1: CGPoint(x: 35.8, y: 65.6), control2: CGPoint(x: 36.8, y: 68.8))
        p.closeSubpath()
        return p
    }()

    static let g25: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 31.6, y: 54.5))
        p.addCurve(to: CGPoint(x: 23.4, y: 46.8), control1: CGPoint(x: 28.6, y: 52), control2: CGPoint(x: 25.8, y: 49.6))
        return p
    }()

    static let g26: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 34.4, y: 51))
        p.addCurve(to: CGPoint(x: 43, y: 45.7), control1: CGPoint(x: 37.2, y: 48.9), control2: CGPoint(x: 40, y: 47.1))
        return p
    }()

    static let g27: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 28.4, y: 47.2))
        p.addCurve(to: CGPoint(x: 16.4, y: 41.6), control1: CGPoint(x: 24.4, y: 44.4), control2: CGPoint(x: 20.6, y: 42.6))
        return p
    }()

    static let g28: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 25.8, y: 72.5))
        p.addCurve(to: CGPoint(x: 29.7, y: 61.4), control1: CGPoint(x: 28, y: 68.6), control2: CGPoint(x: 29, y: 65.4))
        p.addCurve(to: CGPoint(x: 31.3, y: 44.2), control1: CGPoint(x: 30.6, y: 55.4), control2: CGPoint(x: 31, y: 49.6))
        p.addLine(to: CGPoint(x: 33.9, y: 44.2))
        p.addCurve(to: CGPoint(x: 35.5, y: 61.4), control1: CGPoint(x: 34.2, y: 49.6), control2: CGPoint(x: 34.6, y: 55.4))
        p.addCurve(to: CGPoint(x: 39.4, y: 72.5), control1: CGPoint(x: 36.2, y: 65.4), control2: CGPoint(x: 37.2, y: 68.6))
        p.closeSubpath()
        return p
    }()

    static let g29: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 31.4, y: 51))
        p.addCurve(to: CGPoint(x: 19.4, y: 39.2), control1: CGPoint(x: 28, y: 46.6), control2: CGPoint(x: 24, y: 42.6))
        return p
    }()

    static let g30: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 33.6, y: 46.5))
        p.addCurve(to: CGPoint(x: 46.2, y: 36.2), control1: CGPoint(x: 37.4, y: 42.4), control2: CGPoint(x: 41.6, y: 38.8))
        return p
    }()

    static let g31: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 32.2, y: 44))
        p.addCurve(to: CGPoint(x: 33, y: 24.4), control1: CGPoint(x: 31.2, y: 37.4), control2: CGPoint(x: 31.6, y: 30.8))
        return p
    }()

    static let g32: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 23.8, y: 42.6))
        p.addCurve(to: CGPoint(x: 19.2, y: 29.2), control1: CGPoint(x: 21.4, y: 38.4), control2: CGPoint(x: 19.8, y: 34))
        return p
    }()

    static let g33: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 25.6, y: 44.4))
        p.addCurve(to: CGPoint(x: 16, y: 38), control1: CGPoint(x: 22.8, y: 41.6), control2: CGPoint(x: 19.6, y: 39.4))
        return p
    }()

    static let g34: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 42.4, y: 39))
        p.addCurve(to: CGPoint(x: 44.2, y: 26), control1: CGPoint(x: 43.8, y: 34.4), control2: CGPoint(x: 44.6, y: 30.4))
        return p
    }()

    static let g35: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 39.2, y: 42))
        p.addCurve(to: CGPoint(x: 48.8, y: 36.4), control1: CGPoint(x: 41.8, y: 39.4), control2: CGPoint(x: 45, y: 37.4))
        return p
    }()

    static let g36: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 32.6, y: 32.4))
        p.addCurve(to: CGPoint(x: 28.2, y: 20.6), control1: CGPoint(x: 30.4, y: 28.4), control2: CGPoint(x: 28.8, y: 24.8))
        return p
    }()

    static let g37: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 32.8, y: 30))
        p.addCurve(to: CGPoint(x: 39.6, y: 21.2), control1: CGPoint(x: 34.8, y: 26.6), control2: CGPoint(x: 37, y: 23.6))
        return p
    }()
    }

    static func parts(for state: TreeHealthMark) -> [TreePart] {
        switch state {
        case .noBudget:
            return [
                TreePart(path: Geometry.ground, transform: .identity, opacity: 0.15, lineWidth: 0),
                TreePart(path: Geometry.g0, transform: CGAffineTransform(translationX: 32, y: 67.5).rotated(by: 14 * .pi / 180).scaledBy(x: 1.5, y: 1.5), opacity: 0.45, lineWidth: 0),
                TreePart(path: Geometry.g1, transform: .identity, opacity: 0.3, lineWidth: 0.9)
            ]

        case .seedling:
            return [
                TreePart(path: Geometry.ground, transform: .identity, opacity: 0.15, lineWidth: 0),
                TreePart(path: Geometry.g2, transform: .identity, opacity: 1, lineWidth: 0),
                TreePart(path: Geometry.g3, transform: .identity, opacity: 0.82, lineWidth: 0),
                TreePart(path: Geometry.g4, transform: .identity, opacity: 0.35, lineWidth: 0.75),
                TreePart(path: Geometry.g5, transform: .identity, opacity: 1, lineWidth: 0),
                TreePart(path: Geometry.g6, transform: .identity, opacity: 0.35, lineWidth: 0.75),
                TreePart(path: Geometry.g7, transform: .identity, opacity: 0.6, lineWidth: 0)
            ]

        case .sprout:
            return [
                TreePart(path: Geometry.ground, transform: .identity, opacity: 0.15, lineWidth: 0),
                TreePart(path: Geometry.g8, transform: .identity, opacity: 1, lineWidth: 0),
                TreePart(path: Geometry.g9, transform: .identity, opacity: 0.55, lineWidth: 0),
                TreePart(path: Geometry.g10, transform: .identity, opacity: 0.3, lineWidth: 0.8),
                TreePart(path: Geometry.g11, transform: .identity, opacity: 0.72, lineWidth: 0),
                TreePart(path: Geometry.g12, transform: .identity, opacity: 0.3, lineWidth: 0.8),
                TreePart(path: Geometry.g13, transform: .identity, opacity: 0.88, lineWidth: 0),
                TreePart(path: Geometry.g14, transform: .identity, opacity: 0.32, lineWidth: 0.75),
                TreePart(path: Geometry.g15, transform: .identity, opacity: 1, lineWidth: 0),
                TreePart(path: Geometry.g16, transform: .identity, opacity: 0.32, lineWidth: 0.75),
                TreePart(path: Geometry.g17, transform: .identity, opacity: 1, lineWidth: 0),
                TreePart(path: Geometry.g18, transform: .identity, opacity: 0.3, lineWidth: 0.7)
            ]

        case .growing:
            return [
                TreePart(path: Geometry.ground, transform: .identity, opacity: 0.15, lineWidth: 0),
                TreePart(path: Geometry.g19, transform: .identity, opacity: 1, lineWidth: 0),
                TreePart(path: Geometry.g20, transform: .identity, opacity: 1, lineWidth: 1.9),
                TreePart(path: Geometry.g21, transform: .identity, opacity: 1, lineWidth: 1.9),
                TreePart(path: Geometry.g22, transform: .identity, opacity: 1, lineWidth: 1.3),
                TreePart(path: Geometry.g23, transform: CGAffineTransform(translationX: 32, y: 15.5).rotated(by: 8 * .pi / 180).scaledBy(x: 1.18, y: 1.18), opacity: 0.45, lineWidth: 0),
                TreePart(path: Geometry.g23, transform: CGAffineTransform(translationX: 20, y: 20.5).rotated(by: -22 * .pi / 180).scaledBy(x: 1.02, y: 1.02), opacity: 0.45, lineWidth: 0),
                TreePart(path: Geometry.g23, transform: CGAffineTransform(translationX: 44, y: 20.5).rotated(by: 26 * .pi / 180).scaledBy(x: 1.02, y: 1.02), opacity: 0.45, lineWidth: 0),
                TreePart(path: Geometry.g23, transform: CGAffineTransform(translationX: 13.5, y: 29.5).rotated(by: 42 * .pi / 180).scaledBy(x: 0.9, y: 0.9), opacity: 0.45, lineWidth: 0),
                TreePart(path: Geometry.g23, transform: CGAffineTransform(translationX: 50.5, y: 29.5).rotated(by: -38 * .pi / 180).scaledBy(x: 0.9, y: 0.9), opacity: 0.45, lineWidth: 0),
                TreePart(path: Geometry.g23, transform: CGAffineTransform(translationX: 32, y: 25).rotated(by: 3 * .pi / 180).scaledBy(x: 1.12, y: 1.12), opacity: 0.45, lineWidth: 0),
                TreePart(path: Geometry.g23, transform: CGAffineTransform(translationX: 23.5, y: 33.5).rotated(by: 16 * .pi / 180), opacity: 0.45, lineWidth: 0),
                TreePart(path: Geometry.g23, transform: CGAffineTransform(translationX: 40.5, y: 33.5).rotated(by: -12 * .pi / 180), opacity: 0.45, lineWidth: 0),
                TreePart(path: Geometry.g23, transform: CGAffineTransform(translationX: 32, y: 39).scaledBy(x: 0.86, y: 0.86), opacity: 0.45, lineWidth: 0)
            ]

        case .wilting:
            return [
                TreePart(path: Geometry.ground, transform: .identity, opacity: 0.15, lineWidth: 0),
                TreePart(path: Geometry.g24, transform: .identity, opacity: 1, lineWidth: 0),
                TreePart(path: Geometry.g25, transform: .identity, opacity: 1, lineWidth: 1.8),
                TreePart(path: Geometry.g26, transform: .identity, opacity: 1, lineWidth: 1.8),
                TreePart(path: Geometry.g27, transform: .identity, opacity: 0.8, lineWidth: 1.2),
                TreePart(path: Geometry.g23, transform: CGAffineTransform(translationX: 33.5, y: 24).rotated(by: 7 * .pi / 180).scaledBy(x: 1.02, y: 1.02), opacity: 0.4, lineWidth: 0),
                TreePart(path: Geometry.g23, transform: CGAffineTransform(translationX: 23.5, y: 28.5).rotated(by: -20 * .pi / 180).scaledBy(x: 0.9, y: 0.9), opacity: 0.4, lineWidth: 0),
                TreePart(path: Geometry.g23, transform: CGAffineTransform(translationX: 43.5, y: 26.5).rotated(by: 22 * .pi / 180).scaledBy(x: 0.92, y: 0.92), opacity: 0.4, lineWidth: 0),
                TreePart(path: Geometry.g23, transform: CGAffineTransform(translationX: 33, y: 32).scaledBy(x: 0.98, y: 0.98), opacity: 0.4, lineWidth: 0),
                TreePart(path: Geometry.g23, transform: CGAffineTransform(translationX: 41, y: 36.5).rotated(by: -14 * .pi / 180).scaledBy(x: 0.8, y: 0.8), opacity: 0.4, lineWidth: 0),
                TreePart(path: Geometry.g23, transform: CGAffineTransform(translationX: 26, y: 37).rotated(by: 12 * .pi / 180).scaledBy(x: 0.76, y: 0.76), opacity: 0.4, lineWidth: 0),
                TreePart(path: Geometry.g23, transform: CGAffineTransform(translationX: 49.5, y: 32.5).rotated(by: -40 * .pi / 180).scaledBy(x: 0.62, y: 0.62), opacity: 0.4, lineWidth: 0),
                TreePart(path: Geometry.g0, transform: CGAffineTransform(translationX: 47.5, y: 50.5).rotated(by: 42 * .pi / 180).scaledBy(x: 1.12, y: 1.12), opacity: 0.5, lineWidth: 0),
                TreePart(path: Geometry.g0, transform: CGAffineTransform(translationX: 52, y: 60.5).rotated(by: 80 * .pi / 180).scaledBy(x: 0.95, y: 0.95), opacity: 0.3, lineWidth: 0),
                TreePart(path: Geometry.g0, transform: CGAffineTransform(translationX: 19.5, y: 55).rotated(by: -48 * .pi / 180).scaledBy(x: 1.02, y: 1.02), opacity: 0.42, lineWidth: 0),
                TreePart(path: Geometry.g0, transform: CGAffineTransform(translationX: 14.5, y: 65.5).rotated(by: -86 * .pi / 180).scaledBy(x: 0.88, y: 0.88), opacity: 0.22, lineWidth: 0)
            ]

        case .resting:
            return [
                TreePart(path: Geometry.ground, transform: .identity, opacity: 0.15, lineWidth: 0),
                TreePart(path: Geometry.g28, transform: .identity, opacity: 1, lineWidth: 0),
                TreePart(path: Geometry.g29, transform: .identity, opacity: 1, lineWidth: 2.1),
                TreePart(path: Geometry.g30, transform: .identity, opacity: 1, lineWidth: 2.1),
                TreePart(path: Geometry.g31, transform: .identity, opacity: 1, lineWidth: 1.9),
                TreePart(path: Geometry.g32, transform: .identity, opacity: 0.9, lineWidth: 1.3),
                TreePart(path: Geometry.g33, transform: .identity, opacity: 0.75, lineWidth: 1.1),
                TreePart(path: Geometry.g34, transform: .identity, opacity: 0.9, lineWidth: 1.3),
                TreePart(path: Geometry.g35, transform: .identity, opacity: 0.75, lineWidth: 1.1),
                TreePart(path: Geometry.g36, transform: .identity, opacity: 0.85, lineWidth: 1.2),
                TreePart(path: Geometry.g37, transform: .identity, opacity: 0.85, lineWidth: 1.2),
                TreePart(path: Geometry.g0, transform: CGAffineTransform(translationX: 19.2, y: 28.6).rotated(by: -28 * .pi / 180).scaledBy(x: 0.85, y: 0.85), opacity: 0.9, lineWidth: 0),
                TreePart(path: Geometry.g0, transform: CGAffineTransform(translationX: 44.2, y: 25.4).rotated(by: 24 * .pi / 180).scaledBy(x: 0.85, y: 0.85), opacity: 0.9, lineWidth: 0),
                TreePart(path: Geometry.g0, transform: CGAffineTransform(translationX: 28.2, y: 19.8).rotated(by: -14 * .pi / 180).scaledBy(x: 0.95, y: 0.95), opacity: 1, lineWidth: 0),
                TreePart(path: Geometry.g0, transform: CGAffineTransform(translationX: 39.6, y: 20.6).rotated(by: 20 * .pi / 180).scaledBy(x: 0.82, y: 0.82), opacity: 0.92, lineWidth: 0),
                TreePart(path: Geometry.g0, transform: CGAffineTransform(translationX: 33, y: 23.6).rotated(by: 6 * .pi / 180).scaledBy(x: 0.9, y: 0.9), opacity: 1, lineWidth: 0),
                TreePart(path: Geometry.g0, transform: CGAffineTransform(translationX: 22.5, y: 70.6).rotated(by: 96 * .pi / 180), opacity: 0.28, lineWidth: 0),
                TreePart(path: Geometry.g0, transform: CGAffineTransform(translationX: 45.6, y: 71.4).rotated(by: -74 * .pi / 180).scaledBy(x: 0.95, y: 0.95), opacity: 0.22, lineWidth: 0)
            ]
        }
    }
}

/// The drawable states, mirroring `BudgetCalculator.TreeHealth`.
enum TreeHealthMark: Equatable, Sendable {
    case noBudget, seedling, sprout, growing, wilting, resting
}

extension TreeHealthMark {
    init(_ health: BudgetCalculator.TreeHealth) {
        switch health {
        case .noBudget: self = .noBudget
        case .seedling: self = .seedling
        case .sprout:   self = .sprout
        case .growing:  self = .growing
        case .wilting:  self = .wilting
        case .resting:  self = .resting
        }
    }
}

extension GraphicsContext {
    /// Draws tree `parts` authored on `canvas`, scaled to fit and centred in
    /// `size`, tinted with `color` at each part's own opacity.
    ///
    /// Shared by `TreeMark` and `TreeStateGlyph` so both marks composite the same
    /// way — the crowns get their depth from overlapping translucent copies, and
    /// that only holds together if the fit and the shading are identical.
    func drawTree(_ parts: [TreeArt.TreePart], canvas: CGSize, in size: CGSize, color: Color) {
        let scale = min(size.width / canvas.width, size.height / canvas.height)
        let fit = CGAffineTransform(
            translationX: (size.width - canvas.width * scale) / 2,
            y: (size.height - canvas.height * scale) / 2
        ).scaledBy(x: scale, y: scale)

        for part in parts {
            let resolved = part.path.applying(part.transform.concatenating(fit))
            let shading = Shading.color(color.opacity(part.opacity))
            if part.lineWidth > 0 {
                stroke(
                    resolved,
                    with: shading,
                    style: StrokeStyle(lineWidth: part.lineWidth * scale, lineCap: .round, lineJoin: .round)
                )
            } else {
                fill(resolved, with: shading)
            }
        }
    }
}

/// Renders a tree mark, scaled to fit and centred in the frame it is given.
struct TreeMark: View {
    let state: TreeHealthMark
    let color: Color

    var body: some View {
        Canvas(opaque: false) { context, size in
            context.drawTree(TreeArt.parts(for: state), canvas: TreeArt.canvas, in: size, color: color)
        }
        .accessibilityHidden(true)
    }
}
