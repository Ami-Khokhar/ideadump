import Foundation

/// What the share extension tells the user when it saved nothing.
///
/// Both failures used to share one sentence, so a report of "couldn't find an
/// amount" could not be told apart from "the extension never received any
/// text". The decision is a value here because the share extension has no test
/// target: this is the part of its behaviour `TapLogTests` can hold.
enum ShareOutcome: Equatable {
    /// The sheet handed over no readable text at all.
    case nothingShared
    /// Text arrived, but the parser found no amount in it.
    case noReadableAmount

    /// The outcome for a finished parse, or `nil` when it found an amount the
    /// extension can save. A zero amount is treated as unreadable, which is the
    /// same rule the extension applied before this value existed.
    static func of(_ parsed: ShareParse) -> ShareOutcome? {
        if let amount = parsed.amount, amount > 0 { return nil }
        return parsed.hasText ? .noReadableAmount : .nothingShared
    }

    /// What the extension shows for this outcome, and what it shows in the
    /// saved case.
    var message: String {
        switch self {
        case .nothingShared:
            return "Nothing was shared with TapLog. Open TapLog to enter an expense manually."
        case .noReadableAmount:
            return "Shared text had no amount TapLog could read. Open TapLog to enter it manually."
        }
    }
}
