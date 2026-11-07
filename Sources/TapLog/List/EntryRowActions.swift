import SwiftUI

/// What a History row offers, as a plain value rather than view code.
///
/// The row's visible edit and delete controls and its deliberate-only swipe are
/// the behaviour issue #58 changed, and a `View` is not something the test
/// target can inspect. Keeping the decision in this value lets
/// `EntryRowActionsTests` fail when a control disappears or a full swipe is
/// allowed again, and leaves `EntryListView` as a renderer of that value.
struct EntryRowActions: Equatable {
    /// The swipe action that pairs with the visible controls. Archive in the
    /// active list, its mirror in the Archived list.
    enum Swipe: Equatable {
        case archive
        case unarchive
    }

    let showsEdit: Bool
    let showsDelete: Bool
    /// A full swipe must never run the swipe action on its own.
    let allowsFullSwipe: Bool
    let swipe: Swipe
    /// At accessibility text sizes the two 44-point controls would take 108
    /// points of the row's width, leaving the category and amount truncated on
    /// a 375-point phone. There they move below the row and keep their full
    /// size instead of squeezing it.
    let stacksControlsBelowRow: Bool

    init(showingArchived: Bool, dynamicTypeSize: DynamicTypeSize) {
        showsEdit = true
        showsDelete = true
        allowsFullSwipe = false
        swipe = showingArchived ? .unarchive : .archive
        stacksControlsBelowRow = dynamicTypeSize.isAccessibilitySize
    }
}
