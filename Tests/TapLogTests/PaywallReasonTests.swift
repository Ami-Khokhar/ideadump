import XCTest
@testable import TapLog

/// Pro is the one screen that asks for money, and the Settings row is the one
/// place a user asks to see it. The copy on that screen switches on
/// `PaywallView.Reason`, so a wrong reason passed from Settings tells a user
/// with no budgets that their grove is full — the exact regression this fix
/// removes.
///
/// The call site is asserted against its source, the same way
/// `PrivacyViewTests.testSettingsLinksToALabelledPrivacyDestination` does,
/// because the sheet is presented from a SwiftUI view body that a unit test
/// cannot tap.
final class PaywallReasonTests: XCTestCase {
    /// .../Tests/TapLogTests/PaywallReasonTests.swift -> the repository root.
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testSettingsOpensTheSettingsPaywallReason() throws {
        let settings = try String(
            contentsOf: repoRoot.appendingPathComponent("Sources/TapLog/Settings/SettingsView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(
            settings.contains("PaywallView(reason: .settings)"),
            "Settings must open Pro with the settings reason so its copy matches why the sheet opened"
        )
        XCTAssertFalse(
            settings.contains("PaywallView(reason: .anotherTree)"),
            "Settings must not borrow the fourth-tree reason; that copy claims the user's grove is full"
        )
    }

    func testSettingsReasonDoesNotClaimTheGroveIsFull() {
        let subhead = PaywallView.Reason.settings.subhead

        XCTAssertFalse(
            subhead.localizedCaseInsensitiveContains("grove is full"),
            "a user who opened Pro on purpose has not hit a limit, so the Settings copy must not say the grove is full"
        )
    }
}
