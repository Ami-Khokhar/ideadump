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

    /// Set while a transfer holds the file. Main-thread only: the share sheet
    /// and the delete-all confirmation both run there.
    private(set) static var isTransferActive = false

    /// Writes the payload for a transfer about to hand it out and marks the
    /// transfer active. Called from the `Transferable` representation.
    static func begin(text: String) throws {
        try Data(text.utf8).write(to: url, options: .atomic)
        isTransferActive = true
    }

    /// Ends a transfer — completed or cancelled — and removes the file. A
    /// no-op when nothing is active, so a screen closing without a share
    /// cannot delete a file it does not own.
    static func end() {
        guard isTransferActive else { return }
        isTransferActive = false
        try? FileManager.default.removeItem(at: url)
    }

    /// Part of the delete-all cleanup: the export is a copy of the history the
    /// user just erased. Skipped while a transfer is active — deleting the
    /// file under an in-flight share would break the transfer, and that
    /// transfer's own `end()` removes the file when it finishes.
    static func sweep() {
        guard !isTransferActive else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
