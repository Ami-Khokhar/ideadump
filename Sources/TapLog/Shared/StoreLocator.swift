import Foundation
import SwiftData

/// Locates the shared SwiftData store. The store lives in the App Group container so the
/// widget and share-extension targets (M3/M4) can read and write the same data.
///
/// A non-nil `containerURL` does not guarantee access: free Apple IDs cannot provision
/// App Group entitlements, yet iOS may still return a group path that the sandbox refuses
/// to write to. Candidates are therefore probed for writability, and a candidate SwiftData
/// cannot open is skipped in favour of on-device Application Support so the app always runs.
enum StoreLocator {
    static let appGroupID = "group.dev.amteshwar.taplog"
    static let storeFileName = "TapLog.store"

    /// Defaults shared between the app and its extensions, so counters recorded by
    /// the widget or Siri are visible to the app (and vice versa). Falls back to
    /// the per-process standard defaults when the App Group isn't provisioned,
    /// matching the store's own fallback behavior.
    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// Resolved once per process: group-container store when present and provably
    /// writable, otherwise Application Support.
    static var storeURL: URL { resolvedCandidates[0] }

    private static let resolvedCandidates: [URL] = candidateStoreURLs()

    enum StoreError: LocalizedError {
        case noUsableStore

        var errorDescription: String? {
            "TapLog could not open its expense store."
        }
    }

    /// One container per process, opened once.
    ///
    /// This memoisation is load-bearing, not an optimisation. `TapLogApp.init`
    /// opens a container at launch, and `LogExpenseIntent` declares
    /// `openAppWhenRun = false` while living only in the app target — so when Siri
    /// runs it, iOS boots *the app's own process* in the background and `perform()`
    /// executes alongside the container the app already opened. Opening a second
    /// `ModelContainer` on the same store file throws; the candidate loop then ran
    /// out of locations and hit `fatalError`, killing the process. That crash is
    /// what Siri reports as "something went wrong".
    ///
    /// `static let` gives lazy, once-only, thread-safe initialisation, so every
    /// caller in a process now shares the container — which also means a Siri log
    /// lands in the same store the UI is observing instead of a second file.
    private static let cachedContainer: Result<ModelContainer, Error> = {
        do { return .success(try openContainer(candidates: resolvedCandidates, pinOnSuccess: true)) }
        catch { return .failure(error) }
    }()

    /// Throwing accessor for App Intents. A store that cannot be opened has to
    /// surface as a spoken Siri error, never as a crash.
    static func container() throws -> ModelContainer {
        try cachedContainer.get()
    }

    /// App-launch accessor. A store we cannot open at all leaves nothing to show,
    /// so failing loudly at launch is still the right behaviour here.
    static func makeContainer() -> ModelContainer {
        do {
            return try container()
        } catch {
            fatalError("Failed to create ModelContainer at any candidate location: \(error)")
        }
    }

    /// Test seam: opens a fresh, uncached container from an explicit candidate
    /// list, so the fallback chain can be exercised against real directories.
    static func makeContainer(candidates: [URL]) -> ModelContainer {
        do {
            return try openContainer(candidates: candidates)
        } catch {
            fatalError("Failed to create ModelContainer at any candidate location: \(error)")
        }
    }

    /// Opens the store at the first candidate SwiftData can actually use. A sandbox-denied
    /// or half-created store is skipped instead of fatal — a stranded store beats a crash.
    private static func openContainer(candidates: [URL], pinOnSuccess: Bool = false) throws -> ModelContainer {
        for url in candidates {
            do {
                let configuration = ModelConfiguration(url: url)
                let container = try ModelContainer(
                    for: Entry.self, SpendCategory.self,
                    configurations: configuration
                )
                if pinOnSuccess { pin(url) }
                return container
            } catch {
                print("TapLog: SwiftData store unusable at \(url.path): \(error) — trying next location")
            }
        }
        throw StoreError.noUsableStore
    }

    /// Group-container store first (only when writable), Application Support
    /// last — except that a location already holding data always wins.
    private static func candidateStoreURLs() -> [URL] {
        var candidates: [URL] = []
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID),
           isWritableDirectory(groupURL) {
            candidates.append(groupURL.appendingPathComponent(storeFileName))
        }
        candidates.append(applicationSupportStoreURL)

        return orderedCandidates(
            candidates,
            pinned: pinnedStoreURL,
            storeExists: { FileManager.default.fileExists(atPath: $0.path) }
        )
    }

    /// Decides which candidate to try first. Pure and injectable so the rules
    /// below can be tested without a real filesystem or defaults.
    ///
    /// Two rules, in order:
    ///
    /// 1. A pin wins — but only if the store it names is still on disk. An
    ///    honoured pin pointing at a deleted file would have SwiftData create a
    ///    fresh empty store at that path, which looks exactly like data loss.
    /// 2. Otherwise prefer whichever candidate already holds a store. Plain
    ///    preference order would open the empty App Group store the first time
    ///    the entitlement becomes available, abandoning a fallback full of
    ///    history — and pinning alone does not save it, because that history was
    ///    pinned while `sharedDefaults` was still the standard suite.
    ///
    /// Nothing is copied between locations. Silently migrating a live SwiftData
    /// store is a larger risk than continuing to use the one that has the data.
    static func orderedCandidates(
        _ candidates: [URL],
        pinned: URL?,
        storeExists: (URL) -> Bool
    ) -> [URL] {
        var ordered = candidates

        func promote(_ url: URL) {
            guard let index = ordered.firstIndex(of: url), index != 0 else { return }
            ordered.remove(at: index)
            ordered.insert(url, at: 0)
        }

        if let pinned, storeExists(pinned), ordered.contains(pinned) {
            promote(pinned)
            return ordered
        }

        if let holdingData = ordered.first(where: storeExists) {
            promote(holdingData)
        }
        return ordered
    }

    /// Defaults key holding the store location this install settled on.
    private static let pinnedStoreKey = "TapLog.pinnedStorePath"

    /// Every suite the pin is mirrored across.
    ///
    /// `sharedDefaults` alone is not enough: it *is* the standard suite while
    /// the App Group is unavailable, and silently becomes the group suite once
    /// the entitlement lands — so a pin written during the fallback era would be
    /// invisible at exactly the moment it needs to be read. Writing both, and
    /// reading both, keeps the record legible across that transition.
    private static var pinSuites: [UserDefaults] {
        var suites: [UserDefaults] = [.standard]
        if let group = UserDefaults(suiteName: appGroupID) { suites.append(group) }
        return suites
    }

    /// The remembered location, or nil on a first run. When the suites disagree,
    /// the pin whose store actually exists wins.
    private static var pinnedStoreURL: URL? {
        let pins = pinSuites
            .compactMap { $0.string(forKey: pinnedStoreKey) }
            .map { URL(fileURLWithPath: $0) }
        return pins.first { FileManager.default.fileExists(atPath: $0.path) } ?? pins.first
    }

    /// Records the location that actually opened, in every suite, so the record
    /// survives the App Group appearing or disappearing.
    private static func pin(_ url: URL) {
        for defaults in pinSuites {
            defaults.set(url.path, forKey: pinnedStoreKey)
        }
    }

    /// Whether the store in use actually lives in the App Group container — i.e.
    /// whether the widget and share extension can see the same data the app
    /// does. False means TapLog still works, but only inside the app.
    /// Resolved once: the store location is fixed for the life of the process,
    /// so re-deriving it on every SwiftUI body pass would be pure waste.
    static let isUsingSharedStore: Bool = {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else { return false }
        return storeURL.path.hasPrefix(groupURL.path)
    }()

    private static var applicationSupportStoreURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent(storeFileName)
    }

    /// The sandbox can hand out a valid-looking group path while denying every write;
    /// verify by creating and removing a probe file before trusting it with the store.
    private static func isWritableDirectory(_ directory: URL) -> Bool {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let probe = directory.appendingPathComponent(".taplog-write-probe")
        guard FileManager.default.createFile(atPath: probe.path, contents: Data()) else { return false }
        try? FileManager.default.removeItem(at: probe)
        return true
    }
}
