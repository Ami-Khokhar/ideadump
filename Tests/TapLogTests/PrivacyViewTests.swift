import XCTest
@testable import TapLog

/// The privacy screen may only state what the app does. Its copy is asserted as
/// data — `PrivacyView.sections` — so a harmless comment edit cannot break a
/// test, and emptying a section cannot pass. No URL may be linked or left as a
/// placeholder, no contact address may be invented, and no blanket security or
/// legal assurance may be claimed: the public policy page is not linked because
/// none has been approved for hosting.
final class PrivacyViewTests: XCTestCase {
    private var allText: String {
        PrivacyView.sections
            .map { "\($0.title) \($0.body)" }
            .joined(separator: "\n")
    }

    func testNoPlaceholderLinkOrInventedContact() {
        XCTAssertFalse(allText.contains("http://"), "no URL may be linked or left as a placeholder")
        XCTAssertFalse(allText.contains("https://"), "no URL may be linked or left as a placeholder")
        XCTAssertFalse(allText.contains("mailto:"), "no contact route may be invented")
        XCTAssertNil(
            allText.range(
                of: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#,
                options: .regularExpression
            ),
            "no email address may be invented"
        )
    }

    func testItExplainsEachRequiredTopic() {
        for phrase in [
            "on this device",
            "export",
            "backup",
            "App Store",
            "Siri",
            "Deleting all entries",
        ] {
            XCTAssertTrue(
                allText.localizedCaseInsensitiveContains(phrase),
                "the privacy screen must explain: \(phrase)"
            )
        }
    }

    func testItPromisesNoBlanketAssurance() {
        let lowercased = allText.lowercased()
        for claim in ["100% secure", "fully secure", "bank-level", "legally compliant", "guaranteed"] {
            XCTAssertFalse(lowercased.contains(claim), "no assurance may be claimed: \(claim)")
        }
    }

    /// Apple is named only for the routes Apple handles. The widget and the
    /// Action Button run TapLog's own code and touch no Apple service.
    func testTheWidgetRouteDoesNotClaimAppleHandlesIt() {
        let widget = PrivacyView.sections.first { $0.title.contains("widget") }
        let body = widget?.body ?? ""
        XCTAssertTrue(
            body.localizedCaseInsensitiveContains("TapLog's own code"),
            "the widget route must be described as TapLog's own code on the device"
        )
        XCTAssertFalse(
            body.localizedCaseInsensitiveContains("Apple handles"),
            "no Apple service is involved in a widget log"
        )
        let siri = PrivacyView.sections.first { $0.title.contains("Siri") }
        XCTAssertTrue(
            (siri?.body ?? "").localizedCaseInsensitiveContains("Apple handles"),
            "Apple handles the Siri and Shortcut routes"
        )
    }

    func testThePublicPolicyLinkIsStillPending() {
        XCTAssertTrue(
            allText.localizedCaseInsensitiveContains("none has been approved for hosting"),
            "the screen must say the public policy page is not yet hosted"
        )
    }

    func testSettingsLinksToALabelledPrivacyDestination() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let settings = try String(
            contentsOf: root.appendingPathComponent("Sources/TapLog/Settings/SettingsView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            settings.contains("NavigationLink(PrivacyView.settingsRowTitle)"),
            "Settings must link to the privacy screen using its own row title"
        )
        XCTAssertTrue(
            settings.contains("PrivacyView()"),
            "the Privacy destination must open the privacy screen"
        )
    }
}
