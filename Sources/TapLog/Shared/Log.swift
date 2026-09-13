import Foundation
import OSLog

/// Where the app says what went wrong.
///
/// Every failure in TapLog is survivable by design — a save that fails leaves the
/// UI standing, a store that won't open falls back to another location. That makes
/// the diagnostic the only evidence any of it happened, and `print` is the one
/// channel that produces no evidence: it is visible in Xcode and nowhere else, so
/// on a TestFlight device the answer to "my expense vanished" is silence.
///
/// `Logger` writes to the unified log instead, which Console.app and a sysdiagnose
/// can both read after the fact.
///
/// Nothing here ever takes an amount, a note, or a category name. The app's whole
/// claim is that spending data stays on the device, and a log the user can export
/// and mail to a stranger is not the place to start making exceptions. Error text
/// and file paths are marked public so they survive redaction; that is the point
/// of logging them at all.
enum Log {
    private static let subsystem = "dev.amteshwar.taplog"

    /// Opening, choosing, healing and pinning the SwiftData store.
    static let store = Logger(subsystem: subsystem, category: "store")
    /// Writing, undoing and deleting entries from any front door.
    static let capture = Logger(subsystem: subsystem, category: "capture")
    /// Siri, Shortcuts and widget intents.
    static let intents = Logger(subsystem: subsystem, category: "intents")
    /// Streaks, recap scheduling and notification permission.
    static let retention = Logger(subsystem: subsystem, category: "retention")
    /// The share extension, which runs in another process.
    static let share = Logger(subsystem: subsystem, category: "share")

    /// Formats an error for the log without pulling the user's data in with it.
    ///
    /// `String(describing:)` on a Core Data error is not safe here: its userInfo
    /// can carry the offending managed object, and its description then spells
    /// out the amount and the note. Every call site interpolates this as
    /// `.public`, so that text would survive redaction and land in any
    /// sysdiagnose the user sends to support. Domain and code identify the
    /// failure for a developer and describe nothing the user bought.
    static func describe(_ error: some Error) -> String {
        let ns = error as NSError
        return "\(ns.domain) \(ns.code)"
    }
}
