import Foundation
import WidgetKit

/// Which of TapLog's widget surfaces the user has actually placed.
///
/// The setup screen used to print the same four instruction chains forever,
/// including for widgets already sitting on the user's Home Screen. Asking
/// WidgetKit what is installed turns those rows from a standing chore into a
/// one-word confirmation, which is most of why the card was long.
@MainActor
final class FrontDoorInventory: ObservableObject {

    /// Nil until a query answers — the UI shows neither "Added" nor steps while
    /// it is unknown, rather than flashing the wrong one. A failed query also
    /// leaves nil: WidgetKit declining to answer is not the same as the user
    /// having nothing installed, and claiming the latter would tell them to
    /// re-add a widget they already have.
    @Published private(set) var hasHomeScreenWidget: Bool?
    @Published private(set) var hasLockScreenWidget: Bool?
    @Published private(set) var hasControl: Bool?

    /// Widget families that live on the Home Screen (or Today view).
    private static let homeScreenFamilies: Set<WidgetFamily> = [
        .systemSmall, .systemMedium, .systemLarge,
    ]

    /// Families that live on the Lock Screen. `accessoryInline` is included for
    /// completeness even though `SpendWidget` doesn't offer it — the check asks
    /// "is one of ours up there", not "is it the family we expected".
    private static let lockScreenFamilies: Set<WidgetFamily> = [
        .accessoryCircular, .accessoryRectangular, .accessoryInline,
    ]

    /// Refreshes all three flags. Safe to call repeatedly; the screen calls it
    /// on appear and whenever the app comes back to the foreground, which is
    /// exactly when the answer is likely to have changed.
    func refresh() async {
        if let families = await installedFamilies() {
            hasHomeScreenWidget = !families.isDisjoint(with: Self.homeScreenFamilies)
            hasLockScreenWidget = !families.isDisjoint(with: Self.lockScreenFamilies)
        } else {
            hasHomeScreenWidget = nil
            hasLockScreenWidget = nil
        }

        if #available(iOS 18.0, *) {
            hasControl = try? await !ControlCenter.shared.currentControls().isEmpty
        } else {
            // Controls don't exist before iOS 18, so the row isn't shown there
            // and this stays unknown.
            hasControl = nil
        }
    }

    /// The families of every installed TapLog widget, or nil when WidgetKit
    /// couldn't answer. The async `currentConfigurations()` is iOS 18+, so the
    /// completion-handler form is used to keep this working on iOS 17.
    private func installedFamilies() async -> Set<WidgetFamily>? {
        await withCheckedContinuation { continuation in
            WidgetCenter.shared.getCurrentConfigurations { result in
                switch result {
                case .success(let infos):
                    continuation.resume(returning: Set(infos.map(\.family)))
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
