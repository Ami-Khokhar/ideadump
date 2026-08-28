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
    /// last — except that a location already in use always wins.
    ///
    /// Without that exception the choice silently flipped underneath the user.
    /// A build that once fell back to Application Support accumulates real
    /// history there; the day the App Group becomes provisionable, plain
    /// preference order would move the app to the (empty) group store and every
    /// expense would look deleted. Pinning keeps the app pointed at the store
    /// that holds the data. Nothing is copied between locations — a silent
    /// migration of a live SwiftData store is a worse risk than staying put.
    private static func candidateStoreURLs() -> [URL] {
        var candidates: [URL] = []
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID),
           isWritableDirectory(groupURL) {
            candidates.append(groupURL.appendingPathComponent(storeFileName))
        }
        candidates.append(applicationSupportStoreURL)

        if let pinned = pinnedStoreURL,
           let index = candidates.firstIndex(of: pinned), index != 0 {
            candidates.remove(at: index)
            candidates.insert(pinned, at: 0)
        }
        return candidates
    }

    /// Defaults key holding the store location this install settled on.
    private static let pinnedStoreKey = "TapLog.pinnedStorePath"

    /// The remembered location, or nil on a first run. A pin naming somewhere no
    /// longer offered (the group went away) is ignored rather than honoured, so
    /// the normal preference order resumes instead of stranding the app.
    private static var pinnedStoreURL: URL? {
        guard let path = sharedDefaults.string(forKey: pinnedStoreKey) else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// Records the location that actually opened. Written to the shared suite so
    /// every target agrees; when the App Group is unavailable that suite is the
    /// per-process standard defaults, which is the best that can be done —
    /// without the entitlement the targets genuinely cannot share a store.
    private static func pin(_ url: URL) {
        sharedDefaults.set(url.path, forKey: pinnedStoreKey)
    }

    /// Whether the store in use actually lives in the App Group container — i.e.
    /// whether the widget and share extension can see the same data the app
    /// does. False means TapLog still works, but only inside the app.
    static var isUsingSharedStore: Bool {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else { return false }
        return storeURL.path.hasPrefix(groupURL.path)
    }

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
