import Foundation

/// A Lock Screen (accessory) widget family, and the one route it opens.
///
/// Kept as data rather than written inline in the widget so that a future edit
/// which points an accessory at a link the app cannot resolve fails a test
/// instead of shipping a tap that goes nowhere. It is also the single owner of
/// the capture route: the widget uses `captureURL` at every site, so the copies
/// cannot drift apart.
enum AccessoryWidgetRoute: String, CaseIterable {
    case circular
    case rectangular

    /// `taplog://log` — the app's existing capture deep link, accepted by
    /// `CapturePrefill(url:)` as a link with no pre-filled fields.
    static let captureURL = URL(string: "taplog://log")!

    /// The link this accessory opens. A family that needs a different route
    /// later gets its own case and value rather than a second literal.
    var url: URL { Self.captureURL }

    /// What VoiceOver speaks for this accessory. It is the same words the
    /// rectangular widget shows, so the spoken label and the visible prompt
    /// stay aligned.
    var label: String { "Log expense" }
}
