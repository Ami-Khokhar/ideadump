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

    // MARK: - Candidate ordering

    private let groupStore = URL(fileURLWithPath: "/group/TapLog.store")
    private let fallbackStore = URL(fileURLWithPath: "/support/TapLog.store")

    private func ordered(
        _ candidates: [URL],
        pinned: URL? = nil,
        withData: Set<URL> = [],
        existing: Set<URL> = []
    ) -> [URL] {
        // A store holding history necessarily exists, so callers never have to
        // state it twice.
        let onDisk = existing.union(withData)
        return StoreLocator.orderedCandidates(
            candidates,
            pinned: pinned,
            hasData: { withData.contains($0) },
            storeExists: { onDisk.contains($0) }
        )
    }

    /// Plain preference order, with nothing pinned and nothing on disk.
    func testGroupStoreIsPreferredOnAFirstRun() {
        XCTAssertEqual(ordered([groupStore, fallbackStore]).first, groupStore)
    }

    /// The regression this ordering exists for: history accumulated in the
    /// fallback while the App Group was unprovisioned must not be abandoned the
    /// day the entitlement lands.
    func testACandidateHoldingDataWinsOverAnEmptyPreferredOne() {
        let result = ordered([groupStore, fallbackStore], withData: [fallbackStore])
        XCTAssertEqual(result.first, fallbackStore)
        XCTAssertEqual(result.count, 2, "the other location stays available as a fallback")
    }

    /// The narrower hole: an empty-but-valid store file already sitting in the
    /// group container. File presence alone would promote it and hide the
    /// fallback history behind it.
    func testAnEmptyStoreFileNeverOutranksOneHoldingData() {
        let result = ordered(
            [groupStore, fallbackStore],
            withData: [fallbackStore],
            existing: [groupStore]
        )
        XCTAssertEqual(result.first, fallbackStore)
    }

    /// Both hold history: preference order decides, and nothing is lost either
    /// way because neither is empty.
    func testWhenBothHoldDataThePreferredLocationWins() {
        let result = ordered([groupStore, fallbackStore], withData: [groupStore, fallbackStore])
        XCTAssertEqual(result.first, groupStore)
    }

    func testPinIsHonouredWhenItsStoreHoldsData() {
        let result = ordered([groupStore, fallbackStore], pinned: fallbackStore, withData: [fallbackStore])
        XCTAssertEqual(result.first, fallbackStore)
    }

    /// A pin is not a trump card. Pointing it at an empty store while the other
    /// location holds the user's history must not strand that history.
    func testPinNamingAnEmptyStoreLosesToOneHoldingData() {
        let result = ordered(
            [groupStore, fallbackStore],
            pinned: groupStore,
            withData: [fallbackStore],
            existing: [groupStore]
        )
        XCTAssertEqual(result.first, fallbackStore)
    }

    /// Honouring a pin whose file is gone would have SwiftData create a fresh
    /// empty store there — indistinguishable from data loss.
    func testPinNamingADeletedStoreIsIgnored() {
        let result = ordered([groupStore, fallbackStore], pinned: fallbackStore, existing: [groupStore])
        XCTAssertEqual(result.first, groupStore, "fall through to the location that has a store")
    }

    /// A pin left behind by a location that is no longer offered at all.
    func testPinNamingAnUnavailableLocationIsIgnored() {
        XCTAssertEqual(ordered([fallbackStore], pinned: groupStore, existing: [groupStore]), [fallbackStore])
    }

    /// Both processes see the same filesystem, so they reach the same answer
    /// even if their pins disagree — which is what keeps a racing app and
    /// widget from opening different stores.
    func testDisagreeingPinsStillResolveToTheStoreHoldingData() {
        let asApp = ordered([groupStore, fallbackStore], pinned: groupStore, withData: [fallbackStore], existing: [groupStore])
        let asWidget = ordered([groupStore, fallbackStore], pinned: fallbackStore, withData: [fallbackStore], existing: [groupStore])
        XCTAssertEqual(asApp.first, fallbackStore)
        XCTAssertEqual(asWidget, asApp, "both processes must land on the same store")
    }

    func testOrderingReturnsEveryCandidateExactlyOnce() {
        for pinned: URL? in [nil, groupStore, fallbackStore] {
            for withData in [Set<URL>(), [groupStore], [fallbackStore], [groupStore, fallbackStore]] {
                let result = ordered([groupStore, fallbackStore], pinned: pinned, withData: withData)
                XCTAssertEqual(result.count, 2, "pinned: \(String(describing: pinned)), data: \(withData)")
                XCTAssertEqual(Set(result), [groupStore, fallbackStore])
            }
        }
    }

    func testSingleCandidateIsReturnedUnchanged() {
        XCTAssertEqual(ordered([fallbackStore], withData: [fallbackStore]), [fallbackStore])
        XCTAssertEqual(ordered([fallbackStore]), [fallbackStore])
    }
}
