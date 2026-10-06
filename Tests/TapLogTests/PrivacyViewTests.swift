import XCTest
@testable import TapLog

/// The privacy screen may only state what the app does. No URL may be linked or
/// left as a placeholder, no contact address may be invented, and no blanket
/// security or legal assurance may be claimed — the public policy page is not
/// linked because none has been approved for hosting.
final class PrivacyViewTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(at path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    private var privacySource: String {
        get throws { try source(at: "Sources/TapLog/Settings/PrivacyView.swift") }
    }

    func testNoPlaceholderLinkOrInventedContact() throws {
        let text = try privacySource
        XCTAssertFalse(text.contains("http://"), "no URL may be linked or left as a placeholder")
        XCTAssertFalse(text.contains("https://"), "no URL may be linked or left as a placeholder")
        XCTAssertFalse(text.contains("mailto:"), "no contact route may be invented")
        XCTAssertNil(
            text.range(
                of: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#,
                options: .regularExpression
            ),
            "no email address may be invented"
        )
    }

    func testItExplainsEachRequiredTopic() throws {
        let text = try privacySource
        for phrase in [
            "on this device",
            "export",
            "backup",
            "App Store",
            "Siri",
            "Deleting all entries",
        ] {
            XCTAssertTrue(
                text.localizedCaseInsensitiveContains(phrase),
                "the privacy screen must explain: \(phrase)"
            )
        }
    }

    func testItPromisesNoBlanketAssurance() throws {
        let text = try privacySource.lowercased()
        for claim in ["100% secure", "fully secure", "bank-level", "legally compliant", "guaranteed"] {
            XCTAssertFalse(text.contains(claim), "no assurance may be claimed: \(claim)")
        }
    }

    func testSettingsLinksToALabelledPrivacyDestination() throws {
        let settings = try source(at: "Sources/TapLog/Settings/SettingsView.swift")
        XCTAssertTrue(
            settings.contains("NavigationLink(\"Privacy\")"),
            "Settings must offer a labelled Privacy destination"
        )
        XCTAssertTrue(
            settings.contains("PrivacyView()"),
            "the Privacy destination must open the privacy screen"
        )
    }

    func testThePublicPolicyLinkIsStillPending() throws {
        let text = try privacySource
        XCTAssertTrue(
            text.localizedCaseInsensitiveContains("none has been approved for hosting"),
            "the screen must say the public policy page is not yet hosted"
        )
    }
}
