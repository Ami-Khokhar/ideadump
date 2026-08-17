import SwiftUI

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

    /// Hairline dividers.
    static let hairline = adaptive(light: 0x1C1B1A, dark: 0xF0EEEB, alpha: 0.08)

    /// Undo toast — ink in light, paper in dark.
    static let toast = adaptive(light: 0x1C1B1A, dark: 0xF0EEEB, alpha: 0.94)
    static let toastText = adaptive(light: 0xF5F3F0, dark: 0x1C1B1A)

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
