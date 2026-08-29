import Foundation

/// What the free app can do, and where Pro begins.
///
/// Kept as plain functions with no StoreKit, no views and no storage, so the
/// boundary between free and paid is one small readable thing that can be tested
/// directly rather than inferred from whichever screen happens to check it.
///
/// Three rules, and the first two are about *adding* rather than *keeping*.
/// Nothing already on someone's phone stops working when this ships: every
/// budget they have keeps its tree, keeps counting, and keeps showing up in the
/// grove. What is gated is planting the next one.
enum ProGate {

    /// How many trees the free grove holds.
    ///
    /// Three, because the grove argues visually and one tree cannot make the
    /// argument. What sells this app is the contrast — something thriving beside
    /// something wilting — and a single tree is just a progress bar with leaves.
    /// Three is where a row of trees starts reading as a grove.
    ///
    /// It is also the free tier doing the marketing. With no ad budget, word of
    /// mouth is the only distribution, and people talk about what they were
    /// given rather than what they were shown through glass.
    static let freeBudgetLimit = 3

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

    /// Whether the CSV export is available.
    ///
    /// The highest-intent tap in the app: nobody exports a spreadsheet by
    /// accident, and wanting your data in Numbers is a different relationship
    /// with the app than logging chai. Gating it costs the daily user nothing,
    /// which is the property every good gate has.
    ///
    /// It gates the *convenience*, never the data. Every entry stays readable in
    /// History, on screen, for free, forever — a local-first app that held your
    /// own records hostage would be a worse thing than a subscription.
    static func canExportCSV(isPro: Bool) -> Bool {
        isPro
    }
}
