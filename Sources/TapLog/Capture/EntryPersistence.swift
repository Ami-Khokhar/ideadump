import Foundation

/// Commits a capture change, and makes the refusal visible when the store says no.
///
/// Every save site used to `print` the error and return. The row simply never
/// appeared, the typed amount was wiped by the same code path that runs after a
/// success, and the user was left to conclude they had mistyped. A silent
/// failure in the one action the whole app exists for is the worst place to be
/// quiet.
///
/// `save` is a parameter rather than a captured `ModelContext.save()` because
/// SwiftData offers no supported way to make a real context refuse on demand,
/// and a failure path that only ever runs in production is exactly the one that
/// stays broken.
enum EntryPersistence {

    /// Shown when a brand-new expense could not be written.
    ///
    /// It deliberately does not add "your amount is still here": the amount is
    /// sitting in the hero directly above the toast, and spelling that out ran
    /// the message onto a second line. A taller toast grows upward into the
    /// category tiles, and the toast is hit-testable — which is the tap-stealing
    /// problem its own layout comment exists to prevent.
    static let insertFailureMessage = "Couldn't save that expense — try again."

    /// Shown when an edit could not be written. Nothing changed, so it says so.
    static let editFailureMessage = "Couldn't save that change — nothing changed."

    // History's own refusals. Each one names the row's actual state afterwards,
    // because the animation has already run: the row slid away and slid back,
    // and without a message that reads as the app losing the gesture.
    static let confirmFailureMessage = "Couldn't add that one — it's still pending."
    static let discardFailureMessage = "Couldn't discard that one — it's still pending."
    static let archiveFailureMessage = "Couldn't archive that — nothing changed."
    static let unarchiveFailureMessage = "Couldn't restore that — nothing changed."
    static let deleteFailureMessage = "Couldn't delete that — nothing changed."

    /// Shown when clearing the whole history is refused. The dialog promised to
    /// remove everything permanently, so a refusal has to say that it did not.
    static let clearAllFailureMessage = "Couldn't clear your history — nothing was removed."

    /// Runs `save`. On refusal it undoes the in-memory change via `rollback` and
    /// hands `message` to `report`, returning false so the caller can stop
    /// before any of its success bookkeeping runs.
    @discardableResult
    static func commit(
        message: String,
        save: () throws -> Void,
        rollback: () -> Void,
        report: (String) -> Void
    ) -> Bool {
        do {
            try save()
            return true
        } catch {
            Log.capture.error("\(message, privacy: .public) — \(Log.describe(error), privacy: .public)")
            rollback()
            report(message)
            return false
        }
    }
}
