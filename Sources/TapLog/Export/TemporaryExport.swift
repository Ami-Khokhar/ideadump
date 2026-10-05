import Foundation

/// Lifecycle for the temporary CSV file a share hands to the system.
///
/// `CSVFile` writes the export to a fixed name in the temporary directory every
/// time a transfer starts. A completed *or* cancelled share leaves the file
/// behind, and the file is a plain-text copy of the user's expense history —
/// so it is removed when its transfer ends and swept when the history is
/// deleted. The active mark keeps the sweep from deleting a file a share is
/// still handing over.
enum TemporaryExport {
    static let fileName = "taplog-export.csv"

    static var url: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }

    /// Set while a transfer holds the file. `begin` runs from the share
    /// representation's async closure, which the system may invoke off the main
    /// thread, while `end` and `sweep` run from the UI; the lock keeps the flag
    /// from being read mid-write.
    private static let lock = NSLock()
    private static var transferActive = false

    static var isTransferActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return transferActive
    }

    /// Writes the payload for a transfer about to hand it out and marks the
    /// transfer active. Called from the `Transferable` representation. The lock
    /// covers the write too: marking the transfer active first is what keeps a
    /// concurrent `sweep` from deleting the file between the write and the mark.
    static func begin(text: String) throws {
        lock.lock()
        defer { lock.unlock() }
        transferActive = true
        do {
            try Data(text.utf8).write(to: url, options: .atomic)
        } catch {
            transferActive = false
            throw error
        }
    }

    /// Ends a transfer — completed or cancelled — and removes the file. A
    /// no-op when nothing is active, so a screen closing without a share
    /// cannot delete a file it does not own.
    static func end() {
        lock.lock()
        defer { lock.unlock() }
        guard transferActive else { return }
        transferActive = false
        removeFile()
    }

    /// Part of the delete-all cleanup: the export is a copy of the history the
    /// user just erased. Skipped while a transfer is active — deleting the
    /// file under an in-flight share would break the transfer, and that
    /// transfer's own `end()` removes the file when it finishes.
    static func sweep() {
        lock.lock()
        defer { lock.unlock() }
        guard !transferActive else { return }
        removeFile()
    }

    /// Removes the export if it is there. A failure is logged, not thrown:
    /// the share and delete-all flows are unaffected, but the residual copy is
    /// the one thing this type exists to prevent, so it must leave evidence.
    private static func removeFile() {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Log.store.error("could not remove the temporary export: \(Log.describe(error), privacy: .public)")
        }
    }
}
