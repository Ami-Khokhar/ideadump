import Foundation

/// The capture taps a widget offers, and whether each one can record the
/// activation before the app makes its opening-animation decision.
///
/// Kept as data rather than written inline in the widget for the same reason as
/// `AccessoryWidgetRoute`: a tap that opens a URL reaches the app through
/// `onOpenURL`, which can arrive after the first capture view appears — the
/// widget then flashes part of the opening plant. Home-screen taps therefore run
/// `OpenCaptureIntent` in the widget's own process, which writes the durable
/// pending flag that `ContentView` reads on its first render. Only the accessory
/// families keep a URL, because WidgetKit gives them one whole-widget tap.
///
/// A test pins both halves of that rule, so a tap cannot quietly go back to a
/// URL and reintroduce the flash.
enum WidgetCaptureTap: String, CaseIterable {
    /// Small home-screen widget, the footer line.
    case smallFooter
    /// Medium home-screen widget, the custom-amount button.
    case mediumCustomAmount
    /// Medium home-screen widget, the "Open TapLog" button shown when the store
    /// cannot be read.
    case mediumUnavailable
    /// Lock Screen circular and rectangular accessories, one whole-widget tap.
    case accessory

    /// `true` when this tap runs `OpenCaptureIntent` in-process, so the durable
    /// pending activation exists before the app's first render.
    var recordsActivationBeforeLaunch: Bool {
        self != .accessory
    }

    /// The URL this tap opens when it cannot run an intent, `nil` when it runs
    /// one.
    var url: URL? {
        recordsActivationBeforeLaunch ? nil : AccessoryWidgetRoute.captureURL
    }
}
