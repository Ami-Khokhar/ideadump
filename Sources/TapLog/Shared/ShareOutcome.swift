import Foundation

/// What the share extension tells the user for a finished parse: the amount it
/// will save, or the sentence explaining why nothing was saved.
///
/// Both failures used to share one sentence, so a report of "couldn't find an
/// amount" could not be told apart from "the extension never received any
/// text". The decision is a value here because the share extension has no test
/// target: this is the part of its behaviour `TapLogTests` can hold.
enum ShareOutcome: Equatable {
    /// Text arrived with an amount to save; the extension announces it.
    case saved(Decimal)
    /// The sheet handed over no readable text at all.
    case nothingShared
    /// Text arrived, but the parser found no amount in it.
    case noReadableAmount

    /// The outcome for a finished parse. A zero amount is treated as unreadable,
    /// which is the same rule the extension applied before this value existed.
    /// The amount travels in the saved case so the extension never has to unwrap
    /// the parse a second time to find what it is saving.
    static func of(_ parsed: ShareParse) -> ShareOutcome {
        if let amount = parsed.amount, amount > 0 { return .saved(amount) }
        return parsed.hasText ? .noReadableAmount : .nothingShared
    }

    /// What the extension shows when nothing was saved, and `nil` when there is a
    /// saved entry to announce — that sentence belongs to the save that produced
    /// it, because it differs between a save that succeeded and one that failed.
    var message: String? {
        switch self {
        case .saved:
            return nil
        case .nothingShared:
            return "Nothing was shared with TapLog. Open TapLog to enter an expense manually."
        case .noReadableAmount:
            return "Shared text had no amount TapLog could read. Open TapLog to enter it manually."
        }
    }
}
