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
        do { return .success(try openContainer(candidates: resolvedCandidates)) }
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
    private static func openContainer(candidates: [URL]) throws -> ModelContainer {
        for url in candidates {
            do {
                let configuration = ModelConfiguration(url: url)
                return try ModelContainer(
                    for: Entry.self, SpendCategory.self,
                    configurations: configuration
                )
            } catch {
                print("TapLog: SwiftData store unusable at \(url.path): \(error) — trying next location")
            }
        }
        throw StoreError.noUsableStore
    }

    /// Group-container store first (only when writable), Application Support last.
    private static func candidateStoreURLs() -> [URL] {
        var candidates: [URL] = []
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID),
           isWritableDirectory(groupURL) {
            candidates.append(groupURL.appendingPathComponent(storeFileName))
        }
        candidates.append(applicationSupportStoreURL)
        return candidates
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
