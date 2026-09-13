import SwiftUI

/// The component roles that get a hand-drawn silhouette instead of a perfect
/// rounded rectangle.
///
/// The botanical redesign keeps this family small on purpose: four roles, four
/// base radii, one shared corner-drawing routine. A new component should pick
/// the closest existing role rather than invent a fifth profile — that is how
/// the shapes stay recognizable as one authored family instead of a pile of
/// one-off tweaks.
enum OrganicRole {
    /// Small filter and category pills — capture's category row, list filters.
    case chip
    /// Grid cells and small grouped blocks smaller than a full card.
    case tile
    /// Full-width content — recap cards, budget tree cards, summaries.
    case card
    /// The primary Log action control.
    case action

    /// The corner radius before the per-seed wobble is applied.
    var baseRadius: CGFloat {
        switch self {
        case .chip: 14
        case .tile: 18
        case .card: 22
        case .action: 26
        }
    }
}

/// A rounded-rectangle silhouette whose four corners differ by a few points,
/// so the outline reads as drawn rather than machine-perfect.
///
/// The wobble is deterministic, not random: it comes from a stable hash of
/// `role` and `seed`, so the same chip renders the same corners every launch.
/// Live randomness would make the shape flicker between layout passes, which
/// reads as a bug rather than a personality. Each corner deviates from
/// `role.baseRadius` by at most 20%, which keeps the outline looking authored
/// — a hand-drawn ink line, not a blob.
///
/// Reserve this shape for chips, tiles, cards, and the Log action. Financial
/// values, keypad digits, totals, and progress bars stay geometrically exact.
struct OrganicSurface: Shape {
    let role: OrganicRole
    var seed: String = ""

    func path(in rect: CGRect) -> Path {
        let base = role.baseRadius
        let maxDeviation = base * 0.2
        let deviation = Self.cornerDeviations(role: role, seed: seed, maxDeviation: maxDeviation)
        let maxRadius = min(rect.width, rect.height) / 2

        let topLeft = min(base + deviation.topLeft, maxRadius)
        let topRight = min(base + deviation.topRight, maxRadius)
        let bottomRight = min(base + deviation.bottomRight, maxRadius)
        let bottomLeft = min(base + deviation.bottomLeft, maxRadius)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))

        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + topRight),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )

        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottomLeft),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topLeft, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )

        path.closeSubpath()
        return path
    }

    /// Turns `role` and `seed` into four small, signed offsets — one per corner.
    ///
    /// The hash comes from FNV-1a over the UTF-8 bytes, not Swift's `hashValue`.
    /// `hashValue` is salted at process launch, so it would give each corner a
    /// new wobble every time the app runs. FNV-1a gives the same bytes the same
    /// hash every time, which is what "stable across launches" requires.
    private static func cornerDeviations(
        role: OrganicRole, seed: String, maxDeviation: CGFloat
    ) -> (topLeft: CGFloat, topRight: CGFloat, bottomRight: CGFloat, bottomLeft: CGFloat) {
        let hash = fnv1aHash("\(role)|\(seed)")

        func signedFraction(_ byte: UInt32) -> CGFloat {
            (CGFloat(byte) / 255) * 2 - 1
        }

        let topLeft = signedFraction((hash >> 0) & 0xFF) * maxDeviation
        let topRight = signedFraction((hash >> 8) & 0xFF) * maxDeviation
        let bottomRight = signedFraction((hash >> 16) & 0xFF) * maxDeviation
        let bottomLeft = signedFraction((hash >> 24) & 0xFF) * maxDeviation

        return (topLeft, topRight, bottomRight, bottomLeft)
    }
}

/// FNV-1a over a string's UTF-8 bytes. Deterministic across launches and
/// platforms, unlike Swift's randomized `hashValue`.
private func fnv1aHash(_ string: String) -> UInt32 {
    var hash: UInt32 = 2_166_136_261
    for byte in string.utf8 {
        hash ^= UInt32(byte)
        hash = hash &* 16_777_619
    }
    return hash
}

extension View {
    /// Fills and clips the view to an `OrganicSurface` for the given role.
    ///
    /// Pass a `seed` — a category name or id works well — so sibling chips
    /// share the family look but differ subtly and stay stable across
    /// redraws.
    func organicBackground(_ role: OrganicRole, seed: String = "", fill: Color) -> some View {
        let shape = OrganicSurface(role: role, seed: seed)
        return background(shape.fill(fill)).clipShape(shape)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 28) {
        VStack(alignment: .leading, spacing: 10) {
            Text("chip").font(.caption).foregroundStyle(Theme.textSecondary)
            HStack(spacing: 10) {
                Text("Food")
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .organicBackground(.chip, seed: "Food", fill: Theme.lichen)
                Text("Transit")
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .organicBackground(.chip, seed: "Transit", fill: Theme.lichen)
                Text("Rent")
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .organicBackground(.chip, seed: "Rent", fill: Theme.lichen)
            }
            .foregroundStyle(Theme.ink)
        }

        VStack(alignment: .leading, spacing: 10) {
            Text("tile").font(.caption).foregroundStyle(Theme.textSecondary)
            HStack(spacing: 10) {
                Text("Groceries")
                    .frame(width: 100, height: 72)
                    .organicBackground(.tile, seed: "Groceries", fill: Theme.surface)
                Text("Coffee")
                    .frame(width: 100, height: 72)
                    .organicBackground(.tile, seed: "Coffee", fill: Theme.surface)
            }
            .foregroundStyle(Theme.ink)
        }

        VStack(alignment: .leading, spacing: 10) {
            Text("card").font(.caption).foregroundStyle(Theme.textSecondary)
            Text("This week")
                .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                .padding(16)
                .organicBackground(.card, seed: "weekly-recap", fill: Theme.surface)
                .foregroundStyle(Theme.ink)
        }

        VStack(alignment: .leading, spacing: 10) {
            Text("action").font(.caption).foregroundStyle(Theme.textSecondary)
            Text("Log")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 28).padding(.vertical, 14)
                .organicBackground(.action, seed: "log", fill: Theme.moss)
        }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Theme.paper)
}
