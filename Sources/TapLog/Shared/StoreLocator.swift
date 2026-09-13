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

    /// The store this process actually opened.
    ///
    /// This used to be `resolvedCandidates[0]` — the first location *tried*, not
    /// the one that opened. Whenever the preferred candidate failed (a denied
    /// sandbox, a half-written store), the app quietly ran on the next location
    /// while `storeURL`, `isUsingSharedStore` and the Settings warning built on
    /// them all described a store it was not using. A diagnostic that lies is
    /// worse than none.
    static var storeURL: URL {
        if case .success(let opened) = cachedStore { return opened.url }
        // Nothing opened at all; name the location that would have been tried
        // first so callers still get something coherent to report.
        return candidateStoreURLs().first ?? applicationSupportStoreURL
    }

    /// A container together with the location it was opened from.
    private struct OpenedStore {
        let container: ModelContainer
        let url: URL
    }

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
    private static let cachedStore: Result<OpenedStore, Error> = {
        // Heal before choosing. The copy changes which location holds history,
        // and therefore which one the ordering below will pick.
        healSplitStoreIfNeeded()

        for url in candidateStoreURLs() {
            do {
                let container = try openContainer(at: url)
                pin(url)
                recordHistoryIfPresent(at: url, container: container)
                return .success(OpenedStore(container: container, url: url))
            } catch {
                Log.store.warning("SwiftData store unusable at \(url.path, privacy: .public): \(Log.describe(error), privacy: .public) — trying next location")
            }
        }
        return .failure(StoreError.noUsableStore)
    }()

    /// Throwing accessor for App Intents. A store that cannot be opened has to
    /// surface as a spoken Siri error, never as a crash.
    static func container() throws -> ModelContainer {
        try cachedStore.get().container
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

    /// Opens the store at exactly one location.
    private static func openContainer(at url: URL) throws -> ModelContainer {
        try ModelContainer(
            for: Entry.self, SpendCategory.self,
            configurations: ModelConfiguration(url: url)
        )
    }

    /// Opens the store at the first candidate SwiftData can actually use. A sandbox-denied
    /// or half-created store is skipped instead of fatal — a stranded store beats a crash.
    private static func openContainer(candidates: [URL]) throws -> ModelContainer {
        for url in candidates {
            do {
                return try openContainer(at: url)
            } catch {
                Log.store.warning("SwiftData store unusable at \(url.path, privacy: .public): \(Log.describe(error), privacy: .public) — trying next location")
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

    // MARK: - Healing a split store

    /// What a copy did, so callers and tests can tell "nothing to do" from
    /// "moved 40 entries" rather than inferring it from a Bool.
    struct CopyResult: Equatable {
        var entries = 0
        var categoriesAdded = 0
        var categoriesUpdated = 0

        static let none = CopyResult()
    }

    /// Whether the one-time copy should run.
    ///
    /// Only in one direction and only into an empty destination: from the
    /// Application Support fallback, which holds history, into an App Group
    /// store that has none. That is precisely the split the app can create — log
    /// for a while without the entitlement, then gain it — and it is the state
    /// where the widget and share extension read an empty store while the app
    /// shows a full one.
    ///
    /// Pure and injectable so every branch is testable without a filesystem.
    static func shouldHealSplit(
        group: URL?,
        fallback: URL,
        holdsHistory: (URL) -> Bool
    ) -> Bool {
        guard let group else { return false }
        // The group store already has the user's data, or is the one in use.
        guard !holdsHistory(group) else { return false }
        // Nothing to move.
        return holdsHistory(fallback)
    }

    /// Copies entries and categories from one store into another, row by row.
    ///
    /// Row-by-row through `ModelContext`, never a file copy. The two stores are
    /// separate SwiftData stacks with their own metadata; moving the file would
    /// carry one store's identity into the other's container, and a half-copied
    /// file is unopenable in a way a half-copied row set is not.
    ///
    /// Refuses a destination that already holds entries, which is what makes it
    /// safe to retry: an interrupted copy that never got to write its marker
    /// would otherwise duplicate every row on the next launch.
    @discardableResult
    static func copyStore(from source: ModelContainer, to destination: ModelContainer) throws -> CopyResult {
        let from = ModelContext(source)
        let into = ModelContext(destination)

        var probe = FetchDescriptor<Entry>()
        probe.fetchLimit = 1
        guard try into.fetch(probe).isEmpty else { return .none }

        let entries = try from.fetch(FetchDescriptor<Entry>())
        let categories = try from.fetch(FetchDescriptor<SpendCategory>())
        guard !entries.isEmpty || !categories.isEmpty else { return .none }

        var result = CopyResult()

        // Categories first, so the entries that reference them by key land in a
        // store that can already name them.
        let existing = Dictionary(
            try into.fetch(FetchDescriptor<SpendCategory>()).map { ($0.key, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for category in categories {
            if let destination = existing[category.key] {
                // The destination's copy is a default the app seeded on first
                // open; the source's is the user's, budgets and all.
                destination.name = category.name
                destination.emoji = category.emoji
                destination.sortOrder = category.sortOrder
                destination.logCount = category.logCount
                destination.budgetTarget = category.budgetTarget
                destination.budgetPeriod = category.budgetPeriod
                destination.budgetHealthResetDate = category.budgetHealthResetDate
                result.categoriesUpdated += 1
            } else {
                into.insert(SpendCategory(
                    key: category.key,
                    name: category.name,
                    emoji: category.emoji,
                    sortOrder: category.sortOrder,
                    logCount: category.logCount,
                    budgetTarget: category.budgetTarget,
                    budgetPeriod: category.budgetPeriod,
                    budgetHealthResetDate: category.budgetHealthResetDate
                ))
                result.categoriesAdded += 1
            }
        }

        for entry in entries {
            let copy = Entry(
                amount: entry.amount,
                category: entry.category,
                note: entry.note,
                date: entry.date,
                isArchived: entry.isArchived,
                isPending: entry.isPending,
                intent: entry.intent
            )
            // `init` stamps a fresh `createdAt` and clears the legacy flag; both
            // are the source row's to keep.
            copy.createdAt = entry.createdAt
            into.insert(copy)
            result.entries += 1
        }

        try into.save()
        return result
    }

    /// Runs the copy once, if the split exists. Called before the store is
    /// chosen, because a successful copy changes which location holds history.
    ///
    /// Every failure here is survivable and silent by design: the fallback store
    /// is never modified or deleted, so the worst outcome is that the app keeps
    /// running on it exactly as it did before, with the Settings warning still
    /// telling the truth about sharing.
    private static func healSplitStoreIfNeeded() {
        let group = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            .flatMap { isWritableDirectory($0) ? $0.appendingPathComponent(storeFileName) : nil }
        let fallback = applicationSupportStoreURL

        func holdsHistory(_ url: URL) -> Bool {
            FileManager.default.fileExists(atPath: url.path) && hasDataMarker(url)
        }
        guard shouldHealSplit(group: group, fallback: fallback, holdsHistory: holdsHistory),
              let group else { return }

        do {
            let source = try openContainer(at: fallback)
            let destination = try openContainer(at: group)
            let result = try copyStore(from: source, to: destination)
            guard result != .none else { return }

            // Only now: the marker is what makes the group store win the next
            // ordering decision, so writing it before a successful save would
            // point the app at a store that does not yet have the data.
            markAsHoldingHistory(group)
            Log.store.notice("healed a split store — copied \(result.entries, privacy: .public) entries and \(result.categoriesAdded + result.categoriesUpdated, privacy: .public) categories into the App Group")
        } catch {
            Log.store.error("could not heal the split store: \(Log.describe(error), privacy: .public) — continuing on the existing one")
        }
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
        markAsHoldingHistory(url)
    }

    /// Writes the marker beside `url`.
    private static func markAsHoldingHistory(_ url: URL) {
        // A failed write leaves a populated store looking empty, which is how it
        // would lose a later ordering decision to a genuinely empty one. There
        // is nothing to do about it here beyond saying so — but the attempt
        // repeats on every launch until it lands, so a transient failure heals
        // itself, and a permanently unwritable directory could not have hosted
        // this store in the first place.
        let marker = dataMarkerURL(for: url)
        if !FileManager.default.createFile(atPath: marker.path, contents: Data()) {
            Log.store.warning("could not record the history marker at \(marker.path, privacy: .public) — store selection will fall back to file presence")
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
