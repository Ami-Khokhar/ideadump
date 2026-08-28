import SwiftUI

/// The app's empty state: a seedling, what's missing, and what fills it.
///
/// Every blank screen used to be a system `ContentUnavailableView` with a grey
/// SF Symbol, which is fine and says nothing. The trees are the app's whole idea,
/// and an empty screen is the one place personality costs nothing — nobody is
/// mid-task on a screen with nothing on it.
///
/// It stays small on purpose. A seedling and two lines, not an illustration that
/// takes the screen over: these surfaces are read in a second and left, and a
/// user who has just wiped their history does not want a poster about it.
///
/// The mark is `TreeMark`'s seedling rather than anything new. It is the same
/// "nothing here yet, and that's the normal start" the budget legend already
/// gives that state, and `BudgetsView`'s own empty state has drawn it this way
/// since the trees landed — so this reuses the app's existing vocabulary instead
/// of adding a second one.
struct SeedlingEmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 0) {
            TreeMark(state: .seedling, color: Theme.accent)
                .frame(width: 54, height: 68)
                .entrance()

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 18)
                .entrance(delay: 0.08)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 40)
                .padding(.top, 8)
                .entrance(delay: 0.14)
        }
        .frame(maxWidth: .infinity)
        // The seedling is decorative — `TreeMark` hides itself from VoiceOver, and
        // combining the rest keeps this one stop rather than three.
        .accessibilityElement(children: .combine)
    }
}

#Preview("Seedling empty state") {
    SeedlingEmptyState(
        title: "Nothing logged yet",
        message: "Log your first expense on the Log tab — it takes about 5 seconds."
    )
    .padding(.vertical, 60)
    .frame(maxHeight: .infinity)
    .background(Theme.background)
}
