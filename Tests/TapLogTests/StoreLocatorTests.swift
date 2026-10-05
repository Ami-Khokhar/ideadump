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

    /// `withData` and `existing` are stated independently on purpose. An earlier
    /// version of this helper unioned them, on the reasoning that a store
    /// holding history must exist — which made the one state that actually
    /// carried a bug, a marker outliving its store, impossible to write down.
    /// Callers that want the ordinary case pass `marked:`.
    private func ordered(
        _ candidates: [URL],
        pinned: URL? = nil,
        withData: Set<URL> = [],
        existing: Set<URL> = []
    ) -> [URL] {
        StoreLocator.orderedCandidates(
            candidates,
            pinned: pinned,
            hasData: { withData.contains($0) },
            storeExists: { existing.contains($0) }
        )
    }

    /// The ordinary case: these locations hold history, and so are also on disk.
    private func ordered(
        _ candidates: [URL],
        pinned: URL? = nil,
        marked: Set<URL>,
        alsoExisting: Set<URL> = []
    ) -> [URL] {
        ordered(
            candidates,
            pinned: pinned,
            withData: marked,
            existing: marked.union(alsoExisting)
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
        let result = ordered([groupStore, fallbackStore], marked: [fallbackStore])
        XCTAssertEqual(result.first, fallbackStore)
        XCTAssertEqual(result.count, 2, "the other location stays available as a fallback")
    }

    /// The narrower hole: an empty-but-valid store file already sitting in the
    /// group container. File presence alone would promote it and hide the
    /// fallback history behind it.
    func testAnEmptyStoreFileNeverOutranksOneHoldingData() {
        let result = ordered(
            [groupStore, fallbackStore],
            marked: [fallbackStore],
            alsoExisting: [groupStore]
        )
        XCTAssertEqual(result.first, fallbackStore)
    }

    /// Both hold history: preference order decides, and nothing is lost either
    /// way because neither is empty.
    func testWhenBothHoldDataThePreferredLocationWins() {
        let result = ordered([groupStore, fallbackStore], marked: [groupStore, fallbackStore])
        XCTAssertEqual(result.first, groupStore)
    }

    func testPinIsHonouredWhenItsStoreHoldsData() {
        let result = ordered([groupStore, fallbackStore], pinned: fallbackStore, marked: [fallbackStore])
        XCTAssertEqual(result.first, fallbackStore)
    }

    /// A pin is not a trump card. Pointing it at an empty store while the other
    /// location holds the user's history must not strand that history.
    func testPinNamingAnEmptyStoreLosesToOneHoldingData() {
        let result = ordered(
            [groupStore, fallbackStore],
            pinned: groupStore,
            marked: [fallbackStore],
            alsoExisting: [groupStore]
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
        let asApp = ordered([groupStore, fallbackStore], pinned: groupStore, marked: [fallbackStore], alsoExisting: [groupStore])
        let asWidget = ordered([groupStore, fallbackStore], pinned: fallbackStore, marked: [fallbackStore], alsoExisting: [groupStore])
        XCTAssertEqual(asApp.first, fallbackStore)
        XCTAssertEqual(asWidget, asApp, "both processes must land on the same store")
    }

    func testOrderingReturnsEveryCandidateExactlyOnce() {
        for pinned: URL? in [nil, groupStore, fallbackStore] {
            for withData in [Set<URL>(), [groupStore], [fallbackStore], [groupStore, fallbackStore]] {
                let result = ordered([groupStore, fallbackStore], pinned: pinned, marked: withData)
                XCTAssertEqual(result.count, 2, "pinned: \(String(describing: pinned)), data: \(withData)")
                XCTAssertEqual(Set(result), [groupStore, fallbackStore])
            }
        }
    }

    /// A marker can outlive the store it describes — the store file is deleted
    /// or corrupted while the zero-byte marker beside it survives. Treating the
    /// marker alone as evidence would promote a location SwiftData is about to
    /// recreate empty, hiding the history that survived elsewhere.
    func testAMarkerWithoutItsStoreIsNotEvidenceOfHistory() {
        let result = ordered(
            [groupStore, fallbackStore],
            withData: [groupStore],          // marker survives
            existing: [fallbackStore]        // but only the fallback still has a store
        )
        XCTAssertEqual(result.first, fallbackStore)
    }

    /// The same rule applies when the stale marker is the pinned location.
    func testAPinnedMarkerWithoutItsStoreIsIgnored() {
        let result = ordered(
            [groupStore, fallbackStore],
            pinned: groupStore,
            withData: [groupStore],
            existing: [fallbackStore]
        )
        XCTAssertEqual(result.first, fallbackStore)
    }

    /// Nothing on disk at all: fall through to preference order rather than
    /// trusting a marker with no store anywhere behind it.
    func testStaleMarkersWithNoStoresFallBackToPreferenceOrder() {
        let result = ordered([groupStore, fallbackStore], withData: [fallbackStore])
        XCTAssertEqual(result.first, groupStore)
    }

    func testSingleCandidateIsReturnedUnchanged() {
        XCTAssertEqual(ordered([fallbackStore], marked: [fallbackStore]), [fallbackStore])
        XCTAssertEqual(ordered([fallbackStore]), [fallbackStore])
    }

    // MARK: - Healing a split store

    private func makeStore() throws -> ModelContainer {
        try ModelContainer(
            for: Entry.self, SpendCategory.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// The split the app can actually create: log without the entitlement, then
    /// gain it. The fallback holds the history; the group store is empty.
    func testHealRunsWhenTheFallbackHoldsHistoryAndTheGroupDoesNot() {
        XCTAssertTrue(StoreLocator.shouldHealSplit(
            group: groupStore, fallback: fallbackStore,
            holdsHistory: { $0 == self.fallbackStore }
        ))
    }

    func testHealDoesNotRunWhenTheGroupStoreAlreadyHoldsHistory() {
        XCTAssertFalse(StoreLocator.shouldHealSplit(
            group: groupStore, fallback: fallbackStore,
            holdsHistory: { _ in true }
        ), "copying into a store that already has data is how duplicates happen")
    }

    func testHealDoesNotRunWhenThereIsNothingToMove() {
        XCTAssertFalse(StoreLocator.shouldHealSplit(
            group: groupStore, fallback: fallbackStore,
            holdsHistory: { _ in false }
        ))
    }

    func testHealDoesNotRunWithoutAnAppGroup() {
        XCTAssertFalse(StoreLocator.shouldHealSplit(
            group: nil, fallback: fallbackStore,
            holdsHistory: { _ in true }
        ))
    }

    func testCopyMovesEntriesAndCategories() throws {
        let source = try makeStore(), destination = try makeStore()
        let from = ModelContext(source)
        from.insert(SpendCategory(key: "chai", name: "Chai", emoji: "☕️", sortOrder: 1, logCount: 7,
                                  budgetTarget: 300, budgetPeriod: .monthly))
        from.insert(Entry(amount: 12, category: "chai", note: "morning", intent: .impulse))
        from.insert(Entry(amount: 30, category: "chai"))
        try from.save()

        let result = try StoreLocator.copyStore(from: source, to: destination)
        XCTAssertEqual(result.entries, 2)
        XCTAssertEqual(result.categoriesAdded, 1)

        let into = ModelContext(destination)
        let copied = try into.fetch(FetchDescriptor<Entry>())
        XCTAssertEqual(copied.count, 2)
        XCTAssertEqual(Set(copied.map(\.amount)), [12, 30])
        XCTAssertEqual(copied.first(where: { $0.amount == 12 })?.note, "morning")
        XCTAssertEqual(copied.first(where: { $0.amount == 12 })?.intent, .impulse)

        let category = try XCTUnwrap(into.fetch(FetchDescriptor<SpendCategory>()).first)
        XCTAssertEqual(category.budgetTarget, 300, "a budget is the user's, and has to survive the move")
        XCTAssertEqual(category.logCount, 7)
    }

    /// The guard that makes the copy safe to retry. An interrupted run that
    /// never wrote its marker would otherwise duplicate every row next launch.
    func testCopyRefusesADestinationThatAlreadyHasEntries() throws {
        let source = try makeStore(), destination = try makeStore()
        let from = ModelContext(source)
        from.insert(Entry(amount: 12, category: "chai"))
        try from.save()
        let into = ModelContext(destination)
        into.insert(Entry(amount: 99, category: "food"))
        try into.save()

        XCTAssertEqual(try StoreLocator.copyStore(from: source, to: destination), .none)
        XCTAssertEqual(try ModelContext(destination).fetch(FetchDescriptor<Entry>()).count, 1)
    }

    func testCopyingTwiceDoesNotDuplicate() throws {
        let source = try makeStore(), destination = try makeStore()
        let from = ModelContext(source)
        from.insert(Entry(amount: 12, category: "chai"))
        try from.save()

        XCTAssertEqual(try StoreLocator.copyStore(from: source, to: destination).entries, 1)
        XCTAssertEqual(try StoreLocator.copyStore(from: source, to: destination), .none)
        XCTAssertEqual(try ModelContext(destination).fetch(FetchDescriptor<Entry>()).count, 1)
    }

    /// A category the destination seeded by default must end up carrying the
    /// user's settings, not the default's.
    func testCopyOverwritesASeededCategoryRatherThanDuplicatingIt() throws {
        let source = try makeStore(), destination = try makeStore()
        let from = ModelContext(source)
        from.insert(SpendCategory(key: "chai", name: "Chai", emoji: "☕️", sortOrder: 1, logCount: 9,
                                  budgetTarget: 500, budgetPeriod: .weekly))
        from.insert(Entry(amount: 12, category: "chai"))
        try from.save()
        let into = ModelContext(destination)
        into.insert(SpendCategory(key: "chai", name: "Chai", emoji: "☕️", sortOrder: 1))
        try into.save()

        let result = try StoreLocator.copyStore(from: source, to: destination)
        XCTAssertEqual(result.categoriesAdded, 0)
        XCTAssertEqual(result.categoriesUpdated, 1)

        let categories = try ModelContext(destination).fetch(FetchDescriptor<SpendCategory>())
        XCTAssertEqual(categories.count, 1, "the key already existed; a second row would split the category")
        XCTAssertEqual(categories.first?.budgetTarget, 500)
        XCTAssertEqual(categories.first?.logCount, 9)
    }

    func testCopyFromAnEmptySourceIsANoOp() throws {
        let source = try makeStore(), destination = try makeStore()
        XCTAssertEqual(try StoreLocator.copyStore(from: source, to: destination), .none)
    }

    // MARK: - Retiring a migrated fallback's history

    /// Creates a real on-disk store seeded with the residue a migration
    /// preserves in its source.
    private func seededFallbackStore(in directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(StoreLocator.storeFileName)
        try seedStore(at: url)
        return url
    }

    private func seedStore(at url: URL) throws {
        let container = try ModelContainer(
            for: Entry.self, SpendCategory.self,
            configurations: ModelConfiguration(url: url)
        )
        let context = ModelContext(container)
        context.insert(Entry(amount: Decimal(string: "12")!, category: "chai"))
        context.insert(Entry(amount: Decimal(string: "30")!, category: "chai"))
        try context.save()
    }

    /// The regression this retirement exists for: fallback history copied into
    /// the group store, then wiped by a delete-all, must not come back when the
    /// candidate stores are reopened and the ordering rule runs again.
    func testDeleteAllAfterMigrationCannotResurrectHistoryFromTheFallback() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("taplog-retire-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let fallback = try seededFallbackStore(in: root.appendingPathComponent("fallback"))
        let group = root.appendingPathComponent("group").appendingPathComponent(StoreLocator.storeFileName)
        let destination = try ModelContainer(
            for: Entry.self, SpendCategory.self,
            configurations: ModelConfiguration(url: group)
        )

        XCTAssertEqual(try StoreLocator.copyStore(from: try reopen(fallback), to: destination).entries, 2)
        // The delete-all itself, committed successfully in the active store.
        XCTAssertEqual(try StoreLocator.clearStore(destination), 2)

        XCTAssertTrue(StoreLocator.retireFallbackHistory(activeStore: group, fallback: fallback))

        // Reopen the fallback the way the ordering rule would on the next
        // launch after the active store failed to open.
        let resurrected = try ModelContext(try reopen(fallback))
        XCTAssertEqual(try resurrected.fetch(FetchDescriptor<Entry>()).count, 0, "the fallback still holds entries")
        XCTAssertEqual(try resurrected.fetch(FetchDescriptor<SpendCategory>()).count, 0, "the fallback still holds categories")
        // The active store keeps its clean slate too.
        let active = ModelContext(destination)
        XCTAssertEqual(try active.fetch(FetchDescriptor<Entry>()).count, 0)
    }

    /// A failing retirement must leave the source untouched and say so.
    func testAFailedRetirementPreservesTheFallbackSourceAndReportsFailure() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("taplog-retire-fail-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let fallback = try seededFallbackStore(in: root.appendingPathComponent("fallback"))
        struct ForcedFailure: Error {}

        XCTAssertFalse(StoreLocator.retireFallbackHistory(
            activeStore: root.appendingPathComponent("group").appendingPathComponent(StoreLocator.storeFileName),
            fallback: fallback,
            clear: { _ in throw ForcedFailure() }
        ))

        XCTAssertEqual(
            try ModelContext(try reopen(fallback)).fetch(FetchDescriptor<Entry>()).count,
            2,
            "a failed retirement deleted records the user may still need"
        )
    }

    /// A store the app is already running on was cleared by the delete-all
    /// itself; there is nothing to retire and nothing to fail over.
    func testRetirementIsANoOpWhenTheAppRunsOnTheFallback() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("taplog-retire-same-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let fallback = try seededFallbackStore(in: root.appendingPathComponent("fallback"))
        XCTAssertTrue(StoreLocator.retireFallbackHistory(activeStore: fallback, fallback: fallback))
        XCTAssertEqual(try ModelContext(try reopen(fallback)).fetch(FetchDescriptor<Entry>()).count, 2)
    }

    private func reopen(_ url: URL) throws -> ModelContainer {
        try ModelContainer(
            for: Entry.self, SpendCategory.self,
            configurations: ModelConfiguration(url: url)
        )
    }

    // MARK: - Retiring: the marker, categories, and the failure paths

    private func markerURL(for store: URL) -> URL {
        store.deletingLastPathComponent().appendingPathComponent(".taplog-has-data")
    }

    /// The marker is the half of the fix that stops the ordering rule promoting
    /// a retired fallback, so its removal has to be exercised on its own.
    func testRetiringRemovesTheMarkerSoTheFallbackIsNotPromoted() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("taplog-retire-marker-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let fallback = try seededFallbackStore(in: root.appendingPathComponent("fallback"))
        let group = root.appendingPathComponent("group").appendingPathComponent(StoreLocator.storeFileName)
        try FileManager.default.createDirectory(at: group.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: group)
        try Data().write(to: markerURL(for: fallback))

        func order() -> [URL] {
            StoreLocator.orderedCandidates(
                [group, fallback], pinned: nil,
                hasData: { FileManager.default.fileExists(atPath: markerURL(for: $0).path) },
                storeExists: { FileManager.default.fileExists(atPath: $0.path) }
            )
        }
        XCTAssertEqual(order().first, fallback, "the marker should promote the fallback before retirement")

        XCTAssertTrue(StoreLocator.retireFallbackHistory(activeStore: group, fallback: fallback))

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: markerURL(for: fallback).path),
            "the marker still claims history the fallback no longer holds"
        )
        XCTAssertEqual(order().first, group, "the retired fallback is still promoted")
    }

    /// Categories are configuration, not history: retiring the fallback's
    /// entries must not take the user's budget targets with them.
    func testRetiringKeepsCategoriesAndResetsTheirUsage() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("taplog-retire-categories-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let fallback = try seededFallbackStore(in: root.appendingPathComponent("fallback"))
        let seed = ModelContext(try reopen(fallback))
        seed.insert(SpendCategory(
            key: "chai", name: "Chai", emoji: "☕️", logCount: 7,
            budgetTarget: Decimal(string: "500"), budgetPeriod: .weekly
        ))
        try seed.save()

        XCTAssertTrue(StoreLocator.retireFallbackHistory(
            activeStore: root.appendingPathComponent("group").appendingPathComponent(StoreLocator.storeFileName),
            fallback: fallback
        ))

        let after = ModelContext(try reopen(fallback))
        XCTAssertEqual(try after.fetch(FetchDescriptor<Entry>()).count, 0)
        let categories = try after.fetch(FetchDescriptor<SpendCategory>())
        XCTAssertEqual(categories.count, 1, "retiring history deleted the user's categories")
        XCTAssertEqual(categories.first?.budgetTarget, Decimal(string: "500"), "a budget target was lost")
        XCTAssertEqual(categories.first?.logCount, 0, "category usage still counts deleted entries")
    }

    /// A clear that throws after the marker exists must leave both the marker
    /// and the records: the fallback is still the only copy of that history.
    func testAFailedClearKeepsTheMarkerAndTheEntries() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("taplog-retire-fail-clear-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let fallback = try seededFallbackStore(in: root.appendingPathComponent("fallback"))
        try Data().write(to: markerURL(for: fallback))
        struct ForcedFailure: Error {}

        XCTAssertFalse(StoreLocator.retireFallbackHistory(
            activeStore: root.appendingPathComponent("group").appendingPathComponent(StoreLocator.storeFileName),
            fallback: fallback,
            clear: { _ in throw ForcedFailure() }
        ))

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: markerURL(for: fallback).path),
            "a failed retirement removed the marker"
        )
        XCTAssertEqual(
            try ModelContext(try reopen(fallback)).fetch(FetchDescriptor<Entry>()).count,
            2,
            "a failed retirement deleted records the user may still need"
        )
    }

    /// An unopenable fallback is reported, not treated as an empty store.
    func testAnUnopenableFallbackIsReported() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("taplog-retire-unopenable-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        // A regular file where the store's directory should be.
        let blocked = root.appendingPathComponent("fallback")
        try Data().write(to: blocked)

        XCTAssertFalse(StoreLocator.retireFallbackHistory(
            activeStore: root.appendingPathComponent("group").appendingPathComponent(StoreLocator.storeFileName),
            fallback: blocked.appendingPathComponent(StoreLocator.storeFileName)
        ))
        XCTAssertTrue(FileManager.default.fileExists(atPath: blocked.path))
    }
}
