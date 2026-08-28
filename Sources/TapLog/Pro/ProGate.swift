import Foundation

/// What the free app can do, and where Pro begins.
///
/// Kept as plain functions with no StoreKit, no views and no storage, so the
/// boundary between free and paid is one small readable thing that can be tested
/// directly rather than inferred from whichever screen happens to check it.
///
/// Two rules, and both are about *adding* rather than *keeping*. Nothing already
/// on someone's phone stops working when this ships: every budget they have
/// keeps its tree, keeps counting, and keeps showing up in the grove. What is
/// gated is planting the next one.
enum ProGate {

    /// How many trees the free grove holds.
    ///
    /// One, because one tree is enough to understand what a tree is for. The
    /// pitch for Pro is then a real one — "you clearly want a second" — rather
    /// than a wall in front of a feature nobody has tried.
    static let freeBudgetLimit = 1

    /// Whether another budget can be created.
    ///
    /// Deliberately about the count of budgets that already exist rather than
    /// "has this user hit the wall before": someone who deletes a budget gets
    /// their free slot back, because the alternative is charging them for a
    /// mistake they already undid.
    static func canPlantAnotherTree(existingBudgetCount: Int, isPro: Bool) -> Bool {
        isPro || existingBudgetCount < freeBudgetLimit
    }

    /// Whether the recap's month span is available.
    ///
    /// The weekly recap — the one the notification is about, and the one the
    /// whole retention loop is built on — stays free. The month view is the
    /// longer lens, and it is the thing worth paying for.
    static func canUseMonthlyRecap(isPro: Bool) -> Bool {
        isPro
    }
}
