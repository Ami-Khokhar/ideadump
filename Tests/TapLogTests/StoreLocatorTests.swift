import XCTest
import SwiftData
@testable import TapLog

/// The shared-store contract: same file name, working container, and a defaults
/// suite that stays usable whether or not the App Group is provisioned.
final class StoreLocatorTests: XCTestCase {

    func testStoreFileNameIsStable() {
        XCTAssertEqual(StoreLocator.storeURL.lastPathComponent, "TapLog.store")
    }

    /// All three entitlements files and StoreLocator must agree, or app, widget,
    /// and share extension silently split into separate stores.
    ///
    /// This is the regression test for the original P0: StoreLocator hard-coded
    /// `group.com.example.taplog` while every entitlements file said otherwise.
    func testAppGroupIDMatchesAllEntitlementsFiles() throws {
        let configs = try configsDirectory()
        for name in ["TapLog", "TapLogWidget", "TapLogShare"] {
            let plist = try Data(contentsOf: configs.appendingPathComponent("\(name).entitlements"))
            let xml = try XCTUnwrap(String(data: plist, encoding: .utf8))
            XCTAssertTrue(
                xml.contains(StoreLocator.appGroupID),
                "\(name).entitlements drifted from \(StoreLocator.appGroupID)"
            )
        }
    }

    /// The entitlements files only matter if the generated project actually
    /// references them. Regression guard for the second P0: project.yml lost its
    /// `entitlements:` blocks during a bundle-ID migration, so CODE_SIGN_ENTITLEMENTS
    /// disappeared from all targets and nothing shared on device — while every file
    /// on disk still looked correct.
    func testGeneratedProjectWiresEntitlementsIntoAllThreeTargets() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/TapLogTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root
        let pbxproj = try String(
            contentsOf: root.appendingPathComponent("TapLog.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )
        for name in ["TapLog.entitlements", "TapLogWidget.entitlements", "TapLogShare.entitlements"] {
            XCTAssertTrue(
                pbxproj.contains("Configs/\(name)"),
                "generated project does not reference Configs/\(name) — run xcodegen after editing project.yml"
            )
        }
    }

    private func configsDirectory() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/TapLogTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("Configs")
    }

    func testSharedDefaultsRoundTrips() {
        let key = "test.sharedDefaults.roundTrip"
        defer { StoreLocator.sharedDefaults.removeObject(forKey: key) }

        StoreLocator.sharedDefaults.set(42, forKey: key)
        XCTAssertEqual(StoreLocator.sharedDefaults.integer(forKey: key), 42)
    }

    @MainActor
    func testMakeContainerSucceeds() {
        // fatalError inside makeContainer means reaching this line is the assertion:
        // both the App Group path and its fallback produce a usable container.
        _ = StoreLocator.makeContainer()
    }

    /// Regression test for the Action Button crash on free-provisioned devices:
    /// `containerURL` returned a valid-looking group path the sandbox refused to
    /// write to, and the old single-attempt `fatalError` turned that into
    /// "TapLog quit unexpectedly". An unusable first candidate must now fall
    /// through to the next location instead of crashing.
    @MainActor
    func testMakeContainerFallsBackToNextCandidateWhenFirstIsUnusable() throws {
        let fm = FileManager.default

        // A regular file occupying the store's parent path makes the first
        // candidate unopenable, simulating the sandbox-denied group container.
        let blocked = fm.temporaryDirectory
            .appendingPathComponent("taplog-blocked-\(UUID().uuidString)")
        try Data().write(to: blocked)
        defer { try? fm.removeItem(at: blocked) }

        let fallbackDirectory = fm.temporaryDirectory
            .appendingPathComponent("taplog-fallback-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: fallbackDirectory) }

        let container = StoreLocator.makeContainer(candidates: [
            blocked.appendingPathComponent(StoreLocator.storeFileName),
            fallbackDirectory.appendingPathComponent(StoreLocator.storeFileName),
        ])

        let context = container.mainContext
        context.insert(Entry(
            amount: Decimal(string: "1.25")!,
            category: SpendCategory.fallbackKey,
            note: "fallback regression"
        ))
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Entry>()).count, 1)
    }
}
