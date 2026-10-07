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

    /// Apple is named only for the routes Apple handles. The Action Button runs
    /// a Shortcut, so it belongs with Siri; the Home Screen widget runs TapLog's
    /// own code and touches no Apple service.
    func testEachRouteNamesTheRightParty() {
        let widget = PrivacyView.sections.first { $0.title.contains("widget") }
        let widgetBody = widget?.body ?? ""
        XCTAssertTrue(
            widgetBody.localizedCaseInsensitiveContains("TapLog's own code"),
            "the widget route must be described as TapLog's own code on the device"
        )
        XCTAssertFalse(
            widgetBody.localizedCaseInsensitiveContains("Apple"),
            "no Apple service is involved in a widget tap"
        )

        let shortcuts = PrivacyView.sections.first { $0.title.contains("Siri") }
        XCTAssertEqual(shortcuts?.title, "Siri, Shortcuts and the Action Button")
        XCTAssertTrue(
            (shortcuts?.body ?? "").localizedCaseInsensitiveContains("Apple's Shortcuts"),
            "Apple's Shortcuts handles the voice, Shortcut and Action Button routes"
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
