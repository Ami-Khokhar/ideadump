import SwiftUI
import UIKit

/// Zen design system: warm-neutral paper palette in light mode, warm near-black in
/// dark mode, one sage accent. Everything adapts to the system appearance for free.
enum Theme {
    // MARK: Colors

    /// App background — warm paper in light, warm near-black in dark.
    static let background = adaptive(light: 0xF7F5F2, dark: 0x121110)

    /// Subtle surface for chips, circles, cards.
    static let surface = adaptive(light: 0xEFECE7, dark: 0x1C1B1A)

    /// Slightly stronger surface (chart bars, pressed states).
    static let surfaceStrong = adaptive(light: 0xE7E3DC, dark: 0x242220)

    /// Primary text.
    static let textPrimary = adaptive(light: 0x1C1B1A, dark: 0xF0EEEB)

    /// Secondary text.
    static let textSecondary = adaptive(light: 0x6E6A64, dark: 0x8A857E)

    /// Tertiary / placeholder text.
    static let textTertiary = adaptive(light: 0xA39E96, dark: 0x5C5852)

    /// The single accent — sage. Used for the Log pill, selection, undo.
    static let accent = adaptive(light: 0x6B8F71, dark: 0x7FA085)

    /// Soft accent fill for selected chips.
    static let accentSoft = adaptive(light: 0x6B8F71, dark: 0x7FA085, alpha: 0.14)

    /// Over-budget signal — warm clay, deliberately not red. The budget system's
    /// premise is encouragement rather than judgment, so overspending should read
    /// as tired, not as an alarm.
    static let clay = adaptive(light: 0xB5836A, dark: 0xC08E70)

    /// Hairline dividers.
    static let hairline = adaptive(light: 0x1C1B1A, dark: 0xF0EEEB, alpha: 0.08)

    /// Undo toast — ink in light, paper in dark.
    static let toast = adaptive(light: 0x1C1B1A, dark: 0xF0EEEB, alpha: 0.94)
    static let toastText = adaptive(light: 0xF5F3F0, dark: 0x1C1B1A)

    /// `accent` and `clay` as they read *on the toast*, whose ground is inverted
    /// relative to every other surface in the app. Both accents are tuned per
    /// scheme against the app's own background, so painting a tree on the toast
    /// with them puts the light-mode sage on ink and the dark-mode sage on
    /// paper — each one against the ground it was not chosen for. Swapping the
    /// pair restores the intended contrast without inventing a third green.
    static let toastAccent = adaptive(light: 0x7FA085, dark: 0x6B8F71)
    static let toastClay = adaptive(light: 0xC08E70, dark: 0xB5836A)

    // MARK: Helpers

    /// Builds a dynamic color from two hex values (0xRRGGBB), optionally with alpha.
    static func adaptive(light: UInt32, dark: UInt32, alpha: Double = 1) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            let r = CGFloat((hex >> 16) & 0xFF) / 255
            let g = CGFloat((hex >> 8) & 0xFF) / 255
            let b = CGFloat(hex & 0xFF) / 255
            return UIColor(red: r, green: g, blue: b, alpha: alpha)
        })
    }

    // MARK: Fonts

    /// Big rounded numerals for amounts (hero, recap totals, list amounts).
    static func amount(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

// MARK: - Motion

/// Zen motion language — soft fades and gentle slides, nothing springy or bouncy.
/// The undo toast slides up and fades: a whisper, not an announcement.
enum Motion {
    /// Micro-interactions: presses, chip toggles.
    static let fast: Double = 0.15
    /// Standard entrances and state changes.
    static let standard: Double = 0.38
    /// Big entrances: welcome, recap, covers.
    static let slow: Double = 0.5

    /// The easing the whole app breathes with — a gentle settle, not a bounce.
    static let gentle = Animation.timingCurve(0.25, 0.55, 0.3, 1.0, duration: standard)
    static let gentleFast = Animation.timingCurve(0.25, 0.55, 0.3, 1.0, duration: fast)
    static let gentleSlow = Animation.timingCurve(0.25, 0.55, 0.3, 1.0, duration: slow)
    /// State changes that should feel neutral (totals ticking, list mutations).
    static let stateChange = Animation.easeInOut(duration: standard)
}

/// Zen entrance: fades in and rises 14pt on a gentle curve. Pass `delay` to stagger
/// siblings so the eye lands on the hero first, then drifts down the screen.
struct Entrance: ViewModifier {
    var delay: Double = 0
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .animation(reduceMotion ? nil : Motion.gentle.delay(delay), value: shown)
            .onAppear { shown = true }
    }
}

extension View {
    /// Fade-and-rise entrance on first appear, optionally staggered.
    func entrance(delay: Double = 0) -> some View {
        modifier(Entrance(delay: delay))
    }
}

/// Press feedback: the label settles gently into the tap — a whisper, not a bounce.
struct ZenPress: ButtonStyle {
    var scale: CGFloat = 0.97
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? scale : 1))
            .animation(reduceMotion ? nil : Motion.gentleFast, value: configuration.isPressed)
    }
}

/// Applies the user's appearance override (Settings → Appearance). Must be applied to
/// the app root **and** to every presented sheet/cover: SwiftUI sheets capture the
/// presenter's environment when they appear, so an override changed while a sheet is
/// up would otherwise leave that sheet in the old scheme until it's reopened.
struct AppearanceOverride: ViewModifier {
    @AppStorage("appearanceMode") private var appearanceMode = "system"

    private var scheme: ColorScheme? {
        switch appearanceMode {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    func body(content: Content) -> some View {
        content.preferredColorScheme(scheme)
    }
}

extension View {
    func applyAppearanceOverride() -> some View {
        modifier(AppearanceOverride())
    }
}

/// Pins scrolling content to the underside of a sheet's floating toolbar.
///
/// Every sheet here paints its own cream background and lets content scroll
/// beneath a floating Cancel/Save (or Done) bar. The system's default edge
/// treatment only *blurs* what passes under that bar, which is enough for a
/// photo and not nearly enough for dark text on a flat background — the "Which
/// category?" header stayed readable behind the Cancel pill, half of it poking
/// out to one side. The hard style paints the edge instead of blurring it, so
/// content leaves the screen at the toolbar rather than lingering behind it.
///
/// A no-op below iOS 26, where the navigation bar is a solid strip that already
/// hides what scrolls under it.
extension View {
    @ViewBuilder
    func floatingToolbarScrollEdge() -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectStyle(.hard, for: .top)
        } else {
            self
        }
    }
}

// MARK: - Responsive Amount Font

/// Computes an adaptive font size that shrinks gracefully as the amount string grows,
/// keeping the text within screen bounds while remaining comfortably readable.
enum AmountFont {

    /// Base font size for short amounts (1–6 digits).
    static let baseFontSize: CGFloat = 56

    /// Minimum font size — never shrinks below this.
    static let minFontSize: CGFloat = 34

    /// Returns the font for the given display text, using a monospaced rounded design.
    static func font(for text: String, dynamicTypeSize: DynamicTypeSize = .large) -> Font {
        let size = fontSize(for: text, dynamicTypeSize: dynamicTypeSize)
        return Theme.amount(size)
    }

    /// Returns the matching currency symbol font size.
    static func symbolFont(for text: String, dynamicTypeSize: DynamicTypeSize = .large) -> Font {
        let size = fontSize(for: text, dynamicTypeSize: dynamicTypeSize)
        return Theme.amount(size * 0.5, weight: .semibold)
    }

    /// Computes the adaptive font size based on character count.
    ///
    /// The curve is piecewise-linear:
    /// - 1–6 chars:  baseFontSize (56pt)
    /// - 7–9 chars:  linearly interpolate from 56 → 44pt
    /// - 10–12 chars: linearly interpolate from 44 → 38pt
    /// - 13+ chars:  minFontSize (34pt)
    static func fontSize(for text: String, dynamicTypeSize: DynamicTypeSize = .large) -> CGFloat {
        let count = text.count
        let base: CGFloat
        switch count {
        case 0...6:
            base = baseFontSize
        case 7...9:
            let t = CGFloat(count - 6) / 3.0
            base = baseFontSize - t * (baseFontSize - 44)
        case 10...12:
            let t = CGFloat(count - 9) / 3.0
            base = 44 - t * (44 - 38)
        default:
            base = minFontSize
        }

        let traits = UITraitCollection(preferredContentSizeCategory: dynamicTypeSize.uiContentSizeCategory)
        let scaled = UIFontMetrics(forTextStyle: .largeTitle).scaledValue(for: base, compatibleWith: traits)
        return min(max(minFontSize, scaled), 76)
    }
}

private extension DynamicTypeSize {
    var uiContentSizeCategory: UIContentSizeCategory {
        switch self {
        case .xSmall: .extraSmall
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .xLarge: .extraLarge
        case .xxLarge: .extraExtraLarge
        case .xxxLarge: .extraExtraExtraLarge
        case .accessibility1: .accessibilityMedium
        case .accessibility2: .accessibilityLarge
        case .accessibility3: .accessibilityExtraLarge
        case .accessibility4: .accessibilityExtraExtraLarge
        case .accessibility5: .accessibilityExtraExtraExtraLarge
        @unknown default: .large
        }
    }
}

/// Keeps the currency symbol and amount together as one bounded visual unit.
enum AmountLayout {
    static let longValueFontFloor: CGFloat = 28

    static func fieldHeight(fontSize: CGFloat) -> CGFloat {
        min(max(64, fontSize + 16), 104)
    }

    static func heroHeight(fontSize: CGFloat) -> CGFloat {
        min(max(92, fieldHeight(fontSize: fontSize) + 28), 132)
    }

    static func fieldWidth(text: String, fontSize: CGFloat, maxWidth: CGFloat) -> CGFloat {
        let measured = measuredTextWidth(text: text, fontSize: fontSize)
        return min(max(44, measured + 10), max(44, maxWidth))
    }

    static func measuredTextWidth(text: String, fontSize: CGFloat) -> CGFloat {
        let display = text.isEmpty ? "0" : text
        let font = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .medium)
        return (display as NSString).size(withAttributes: [.font: font]).width
    }

    /// Keeps ordinary values at the normal 34pt floor, while allowing only
    /// unusually long grouped values to shrink enough for a narrow phone.
    static func minimumFontSize(text: String, fontSize: CGFloat, availableWidth: CGFloat) -> CGFloat {
        guard text.count > 9 else { return AmountFont.minFontSize }
        let measured = measuredTextWidth(text: text, fontSize: fontSize)
        guard measured > 0, availableWidth > 0 else { return AmountFont.minFontSize }
        let fitted = fontSize * max(1, availableWidth - 10) / measured
        return max(longValueFontFloor, min(AmountFont.minFontSize, fitted))
    }
}
