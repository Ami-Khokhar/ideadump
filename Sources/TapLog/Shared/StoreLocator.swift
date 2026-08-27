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

    static func makeContainer() -> ModelContainer {
        makeContainer(candidates: resolvedCandidates)
    }

    /// Opens the store at the first candidate SwiftData can actually use. A sandbox-denied
    /// or half-created store is skipped instead of fatal — a stranded store beats a crash.
    static func makeContainer(candidates: [URL]) -> ModelContainer {
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
        fatalError("Failed to create ModelContainer at any candidate location")
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
