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
                if pinOnSuccess {
                    pin(url)
                    recordHistoryIfPresent(at: url, container: container)
                }
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
            hasData: hasDataMarker,
            storeExists: { FileManager.default.fileExists(atPath: $0.path) }
        )
    }

    /// Decides which candidate to try first. Pure and injectable so the rules
    /// below can be tested without a real filesystem or defaults.
    ///
    /// The ordering is driven by evidence of history, not by preference:
    ///
    /// 1. A location known to hold history wins — the pin first if it qualifies,
    ///    otherwise whichever candidate does. Mere file presence is not that
    ///    evidence: an empty-but-valid store file can sit in the App Group
    ///    container (a build opened it, logged nothing, then lost the
    ///    entitlement), and promoting it would hide a fallback full of history.
    /// 2. Failing that, a pin that still points at a real store, then any real
    ///    store, then plain preference order.
    ///
    /// Nothing is ever copied between locations. Silently migrating a live
    /// SwiftData store is a larger risk than continuing to use the one that
    /// already has the data.
    static func orderedCandidates(
        _ candidates: [URL],
        pinned: URL?,
        hasData: (URL) -> Bool,
        storeExists: (URL) -> Bool
    ) -> [URL] {
        var ordered = candidates

        func promote(_ url: URL) -> [URL] {
            if let index = ordered.firstIndex(of: url), index != 0 {
                ordered.remove(at: index)
                ordered.insert(url, at: 0)
            }
            return ordered
        }

        // A marker only counts alongside the store it describes. A marker that
        // outlived its store would otherwise promote a location SwiftData is
        // about to recreate empty, hiding the history that survived elsewhere —
        // the exact failure the marker exists to prevent.
        func holdsHistory(_ url: URL) -> Bool { storeExists(url) && hasData(url) }

        if let pinned, ordered.contains(pinned), holdsHistory(pinned) { return promote(pinned) }
        if let populated = ordered.first(where: holdsHistory) { return promote(populated) }
        if let pinned, ordered.contains(pinned), storeExists(pinned) { return promote(pinned) }
        if let existing = ordered.first(where: storeExists) { return promote(existing) }
        return ordered
    }

    // MARK: - History marker

    /// Sits beside a store that has held at least one entry.
    ///
    /// It exists because "the file is there" and "the file has the user's data"
    /// are different questions, and only the second one should decide which
    /// store to open. Once written it is never removed: a store the user emptied
    /// is still their store.
    private static let dataMarkerName = ".taplog-has-data"

    private static func dataMarkerURL(for store: URL) -> URL {
        store.deletingLastPathComponent().appendingPathComponent(dataMarkerName)
    }

    private static func hasDataMarker(_ store: URL) -> Bool {
        FileManager.default.fileExists(atPath: dataMarkerURL(for: store).path)
    }

    /// Marks `url` as holding history, if it does. Runs once per location: after
    /// the marker exists the check is a file lookup, never a fetch.
    ///
    /// Uses a fresh `ModelContext` rather than `mainContext`, because this runs
    /// during the container's lazy initialisation on whichever thread touched it
    /// first — which for a Siri log or a widget refresh is not the main one.
    private static func recordHistoryIfPresent(at url: URL, container: ModelContainer) {
        guard !hasDataMarker(url) else { return }
        var descriptor = FetchDescriptor<Entry>()
        descriptor.fetchLimit = 1
        let context = ModelContext(container)
        guard let found = try? context.fetch(descriptor), !found.isEmpty else { return }

        // A failed write leaves a populated store looking empty, which is how it
        // would lose a later ordering decision to a genuinely empty one. There
        // is nothing to do about it here beyond saying so — but the attempt
        // repeats on every launch until it lands, so a transient failure heals
        // itself, and a permanently unwritable directory could not have hosted
        // this store in the first place.
        let marker = dataMarkerURL(for: url)
        if !FileManager.default.createFile(atPath: marker.path, contents: Data()) {
            print("TapLog: could not record the history marker at \(marker.path) — store selection will fall back to file presence")
        }
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

    /// The remembered location, or nil on a first run.
    ///
    /// When the two suites disagree — which is exactly what happens across the
    /// App Group appearing — the pin naming a store with history wins, then one
    /// naming a store that at least exists. Suite order is the last resort, not
    /// the first, because it carries no information about where the data is.
    private static var pinnedStoreURL: URL? {
        let pins = pinSuites
            .compactMap { $0.string(forKey: pinnedStoreKey) }
            .map { URL(fileURLWithPath: $0) }
        func storeExists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }
        return pins.first { storeExists($0) && hasDataMarker($0) }
            ?? pins.first(where: storeExists)
            ?? pins.first
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
