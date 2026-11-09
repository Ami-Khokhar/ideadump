import Foundation

/// The capture taps the home-screen widget offers.
///
/// Each one runs `OpenCaptureIntent` in the widget's own process instead of
/// opening `taplog://log`. A URL reaches the app through `onOpenURL`, which can
/// arrive after the first capture view renders, so the widget tap would flash
/// part of the opening plant first; the intent writes the durable pending flag
/// before the system launches the app, so `ContentView` already knows on its
/// first render.
///
/// Named here rather than written inline in the widget so a test can hold every
/// site to that rule: `WidgetCaptureTapTests` reads `SpendWidget.swift` and fails
/// if a tap goes back to a `Link`, if a tap site is missing, or if a tap site
/// exists that this enum does not name. The Lock Screen accessories are not
/// cases: WidgetKit gives an accessory one whole-widget tap, so they keep
/// `.widgetURL` and `AccessoryWidgetRoute` owns their route.
enum WidgetCaptureTap: String, CaseIterable {
    /// Small home-screen widget, the footer line.
    case smallFooter
    /// Medium home-screen widget, the custom-amount button.
    case mediumCustomAmount
    /// Medium home-screen widget, the "Open TapLog" button shown when the store
    /// cannot be read.
    case mediumUnavailable

    /// The argument the widget passes to `captureButton` for this tap.
    var callSite: String { "captureButton(.\(rawValue))" }
}
