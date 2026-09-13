import SwiftUI

/// One hand-inked mark per built-in category — a field-journal stamp, not an
/// emoji or an SF Symbol.
///
/// The app currently mixes three illustration dialects: emoji on category chips,
/// SF Symbols in a few corners, and the custom tree drawings in `TreeArt`. This
/// gives the categories a single consistent dialect of their own: small
/// line-drawn stamps, a few strokes each, legible at 20–24pt. Adopting it on
/// chips and lists is a later change — this file only defines the family.
///
/// Every mark is authored on the same 32×32 canvas, the way `TreeArt` authors
/// its tree marks on a fixed grid, and scaled to fit whatever frame it is
/// given. Do not hand-edit the coordinates without checking the whole set
/// still reads as one family — same stroke weight, same level of detail.
enum BotanicalStamp: String, CaseIterable {
    case chai, food, transport, metro, lunch, groceries, shopping, bills, snacks, health, fun, rent, other

    /// Design-time canvas the coordinates below are authored against.
    static let canvas = CGSize(width: 32, height: 32)

    /// The stroke weight every stamp shares, in canvas units. One weight
    /// across the family keeps the stamps reading as one set instead of
    /// thirteen individual drawings.
    static let strokeWidth: CGFloat = 2.2

    /// Maps a category's stable key to its stamp. Custom categories, and any
    /// key that predates this file, fall back to `.other` — the same fallback
    /// `CategoryLookup` already uses for a deleted category's name and emoji.
    static func stamp(for categoryKey: String) -> BotanicalStamp {
        BotanicalStamp(rawValue: categoryKey) ?? .other
    }

    /// The stamp's line art, authored on `BotanicalStamp.canvas`.
    var path: Path {
        Geometry.path(for: self)
    }
}

private enum Geometry {
    /// A single pointed-leaf shape, reused four times (rotated) to build the
    /// `.health` cross — the same "author one part, place it with a
    /// transform" trick `TreeArt` uses for its leaf crowns.
    static let leaf: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -5))
        p.addCurve(to: CGPoint(x: 2.6, y: 4), control1: CGPoint(x: 3.2, y: -3.2), control2: CGPoint(x: 4.4, y: 0.8))
        p.addCurve(to: CGPoint(x: -2.6, y: 4), control1: CGPoint(x: 0.8, y: 6.2), control2: CGPoint(x: -0.8, y: 6.2))
        p.addCurve(to: CGPoint(x: 0, y: -5), control1: CGPoint(x: -4.4, y: 0.8), control2: CGPoint(x: -3.2, y: -3.2))
        p.closeSubpath()
        return p
    }()

    static func path(for stamp: BotanicalStamp) -> Path {
        switch stamp {
        case .chai:
            var p = Path()
            // Rim.
            p.move(to: CGPoint(x: 11, y: 15))
            p.addLine(to: CGPoint(x: 21, y: 15))
            // Walls and rounded bottom.
            p.move(to: CGPoint(x: 11, y: 15))
            p.addLine(to: CGPoint(x: 12, y: 24))
            p.addCurve(to: CGPoint(x: 20, y: 24), control1: CGPoint(x: 14, y: 26), control2: CGPoint(x: 18, y: 26))
            p.addLine(to: CGPoint(x: 21, y: 15))
            // Handle.
            p.move(to: CGPoint(x: 21, y: 17))
            p.addCurve(to: CGPoint(x: 21, y: 21), control1: CGPoint(x: 25, y: 17.5), control2: CGPoint(x: 25, y: 20.5))
            // Rising steam curl.
            p.move(to: CGPoint(x: 15, y: 12))
            p.addCurve(to: CGPoint(x: 15, y: 5), control1: CGPoint(x: 12.5, y: 10), control2: CGPoint(x: 17.5, y: 7))
            return p

        case .food:
            // A single fork: three tines merging into one handle.
            var p = Path()
            p.move(to: CGPoint(x: 13, y: 14))
            p.addLine(to: CGPoint(x: 13, y: 9))
            p.move(to: CGPoint(x: 16, y: 14))
            p.addLine(to: CGPoint(x: 16, y: 8))
            p.move(to: CGPoint(x: 19, y: 14))
            p.addLine(to: CGPoint(x: 19, y: 9))
            p.move(to: CGPoint(x: 13, y: 14))
            p.addCurve(to: CGPoint(x: 19, y: 14), control1: CGPoint(x: 14, y: 18), control2: CGPoint(x: 18, y: 18))
            p.move(to: CGPoint(x: 16, y: 16))
            p.addLine(to: CGPoint(x: 16, y: 26))
            return p

        case .transport:
            // A bus: rounded body, a window band, two wheels.
            var p = Path(roundedRect: CGRect(x: 8, y: 11, width: 16, height: 10), cornerRadius: 2.5)
            p.addPath(Path(ellipseIn: CGRect(x: 10, y: 21.5, width: 3.6, height: 3.6)))
            p.addPath(Path(ellipseIn: CGRect(x: 18.4, y: 21.5, width: 3.6, height: 3.6)))
            p.move(to: CGPoint(x: 9, y: 16))
            p.addLine(to: CGPoint(x: 23, y: 16))
            return p

        case .metro:
            // A rail: two rails and their sleepers, seen from the platform.
            var p = Path()
            p.move(to: CGPoint(x: 7, y: 12))
            p.addLine(to: CGPoint(x: 25, y: 12))
            p.move(to: CGPoint(x: 7, y: 19))
            p.addLine(to: CGPoint(x: 25, y: 19))
            for x: CGFloat in [10, 14.5, 19, 23.5] {
                p.move(to: CGPoint(x: x, y: 12))
                p.addLine(to: CGPoint(x: x, y: 19))
            }
            return p

        case .lunch:
            // A stacked tiffin carrier with a loop handle.
            var p = Path(roundedRect: CGRect(x: 11, y: 9, width: 10, height: 6.5), cornerRadius: 1.5)
            p.addPath(Path(roundedRect: CGRect(x: 11, y: 16.5, width: 10, height: 8.5), cornerRadius: 1.5))
            p.move(to: CGPoint(x: 14, y: 9))
            p.addCurve(to: CGPoint(x: 18, y: 9), control1: CGPoint(x: 14, y: 5), control2: CGPoint(x: 18, y: 5))
            return p

        case .groceries:
            // An open basket with an arched handle.
            var p = Path()
            p.move(to: CGPoint(x: 9, y: 15))
            p.addLine(to: CGPoint(x: 23, y: 15))
            p.addLine(to: CGPoint(x: 21, y: 25))
            p.addLine(to: CGPoint(x: 11, y: 25))
            p.closeSubpath()
            p.move(to: CGPoint(x: 12, y: 15))
            p.addCurve(to: CGPoint(x: 20, y: 15), control1: CGPoint(x: 13, y: 8), control2: CGPoint(x: 19, y: 8))
            p.move(to: CGPoint(x: 11.5, y: 20))
            p.addLine(to: CGPoint(x: 20.5, y: 20))
            return p

        case .shopping:
            // A paper bag: rectangle body, fold line, two small handles.
            var p = Path()
            p.move(to: CGPoint(x: 10, y: 14))
            p.addLine(to: CGPoint(x: 10, y: 26))
            p.addLine(to: CGPoint(x: 22, y: 26))
            p.addLine(to: CGPoint(x: 22, y: 14))
            p.closeSubpath()
            p.move(to: CGPoint(x: 10, y: 17.5))
            p.addLine(to: CGPoint(x: 22, y: 17.5))
            p.move(to: CGPoint(x: 13, y: 14))
            p.addCurve(to: CGPoint(x: 15, y: 14), control1: CGPoint(x: 13, y: 9.5), control2: CGPoint(x: 15, y: 9.5))
            p.move(to: CGPoint(x: 17, y: 14))
            p.addCurve(to: CGPoint(x: 19, y: 14), control1: CGPoint(x: 17, y: 9.5), control2: CGPoint(x: 19, y: 9.5))
            return p

        case .bills:
            // A receipt: torn bottom edge, two lines of text.
            var p = Path()
            p.move(to: CGPoint(x: 10, y: 8))
            p.addLine(to: CGPoint(x: 22, y: 8))
            p.addLine(to: CGPoint(x: 22, y: 23))
            p.addLine(to: CGPoint(x: 20, y: 25))
            p.addLine(to: CGPoint(x: 18, y: 23))
            p.addLine(to: CGPoint(x: 16, y: 25))
            p.addLine(to: CGPoint(x: 14, y: 23))
            p.addLine(to: CGPoint(x: 12, y: 25))
            p.addLine(to: CGPoint(x: 10, y: 23))
            p.closeSubpath()
            p.move(to: CGPoint(x: 12.5, y: 12.5))
            p.addLine(to: CGPoint(x: 19.5, y: 12.5))
            p.move(to: CGPoint(x: 12.5, y: 16.5))
            p.addLine(to: CGPoint(x: 17.5, y: 16.5))
            return p

        case .snacks:
            // A snack bowl with a few pieces piled above the rim.
            var p = Path()
            p.move(to: CGPoint(x: 10, y: 19))
            p.addLine(to: CGPoint(x: 22, y: 19))
            p.addCurve(to: CGPoint(x: 11, y: 26), control1: CGPoint(x: 22, y: 24), control2: CGPoint(x: 20, y: 26))
            p.addLine(to: CGPoint(x: 21, y: 26))
            p.addCurve(to: CGPoint(x: 22, y: 19), control1: CGPoint(x: 21, y: 26), control2: CGPoint(x: 22, y: 24))
            p.addPath(Path(ellipseIn: CGRect(x: 11.5, y: 13, width: 3.4, height: 3.4)))
            p.addPath(Path(ellipseIn: CGRect(x: 15.3, y: 11, width: 3.4, height: 3.4)))
            p.addPath(Path(ellipseIn: CGRect(x: 19, y: 14, width: 3.4, height: 3.4)))
            return p

        case .health:
            // A leaf-cross: the health-and-growth motif, four leaves reaching
            // out from a shared centre.
            let center = CGPoint(x: 16, y: 16)
            var p = Path()
            p.addPath(leaf.applying(CGAffineTransform(translationX: center.x, y: center.y - 6.5)))
            p.addPath(leaf.applying(CGAffineTransform(translationX: center.x, y: center.y + 6.5).rotated(by: .pi)))
            p.addPath(leaf.applying(CGAffineTransform(translationX: center.x - 6.5, y: center.y).rotated(by: -.pi / 2)))
            p.addPath(leaf.applying(CGAffineTransform(translationX: center.x + 6.5, y: center.y).rotated(by: .pi / 2)))
            return p

        case .fun:
            // A small sparkle: two crossed diamonds.
            var p = Path()
            p.move(to: CGPoint(x: 16, y: 7))
            p.addLine(to: CGPoint(x: 18, y: 16))
            p.addLine(to: CGPoint(x: 16, y: 25))
            p.addLine(to: CGPoint(x: 14, y: 16))
            p.closeSubpath()
            p.move(to: CGPoint(x: 7, y: 16))
            p.addLine(to: CGPoint(x: 16, y: 14))
            p.addLine(to: CGPoint(x: 25, y: 16))
            p.addLine(to: CGPoint(x: 16, y: 18))
            p.closeSubpath()
            return p

        case .rent:
            // A house: pitched roof, walls, a door.
            var p = Path()
            p.move(to: CGPoint(x: 8, y: 17))
            p.addLine(to: CGPoint(x: 16, y: 8))
            p.addLine(to: CGPoint(x: 24, y: 17))
            p.move(to: CGPoint(x: 10, y: 17))
            p.addLine(to: CGPoint(x: 10, y: 25))
            p.addLine(to: CGPoint(x: 22, y: 25))
            p.addLine(to: CGPoint(x: 22, y: 17))
            p.move(to: CGPoint(x: 14.5, y: 25))
            p.addLine(to: CGPoint(x: 14.5, y: 19.5))
            p.addLine(to: CGPoint(x: 17.5, y: 19.5))
            p.addLine(to: CGPoint(x: 17.5, y: 25))
            return p

        case .other:
            // A plain seed pod — the fallback mark for anything uncategorised.
            var p = Path()
            p.move(to: CGPoint(x: 16, y: 9))
            p.addCurve(to: CGPoint(x: 16, y: 25), control1: CGPoint(x: 22, y: 12), control2: CGPoint(x: 22, y: 22))
            p.addCurve(to: CGPoint(x: 16, y: 9), control1: CGPoint(x: 10, y: 22), control2: CGPoint(x: 10, y: 12))
            p.move(to: CGPoint(x: 16, y: 9))
            p.addLine(to: CGPoint(x: 16, y: 6))
            p.move(to: CGPoint(x: 16, y: 11))
            p.addLine(to: CGPoint(x: 16, y: 23))
            return p
        }
    }
}

/// Renders a stamp, scaled to fit and centred in the frame it is given.
/// The category name is already spoken by the surrounding chip or row, so
/// the mark itself stays out of the accessibility tree.
struct BotanicalStampView: View {
    let stamp: BotanicalStamp
    var color: Color = Theme.fern

    var body: some View {
        Canvas(opaque: false) { context, size in
            let canvas = BotanicalStamp.canvas
            let scale = min(size.width / canvas.width, size.height / canvas.height)
            let fit = CGAffineTransform(
                translationX: (size.width - canvas.width * scale) / 2,
                y: (size.height - canvas.height * scale) / 2
            ).scaledBy(x: scale, y: scale)

            let resolved = stamp.path.applying(fit)
            context.stroke(
                resolved,
                with: .color(color),
                style: StrokeStyle(lineWidth: BotanicalStamp.strokeWidth * scale, lineCap: .round, lineJoin: .round)
            )
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    let columns = [GridItem(.adaptive(minimum: 72), spacing: 16)]

    return ScrollView {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(BotanicalStamp.allCases, id: \.self) { stamp in
                VStack(spacing: 6) {
                    BotanicalStampView(stamp: stamp)
                        .frame(width: 24, height: 24)
                    Text(stamp.rawValue)
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(width: 72, height: 64)
            }
        }
        .padding(20)
    }
    .background(Theme.paper)
}
