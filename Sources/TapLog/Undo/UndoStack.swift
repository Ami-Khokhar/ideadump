import SwiftUI

/// Records inverse operations for every mutation and exposes the most recent one as a
/// toast that auto-dismisses after 5 seconds.
@MainActor
final class UndoStack: ObservableObject {
    struct Action: Identifiable {
        let id = UUID()
        let message: String
        /// The budget tree this action moved, when it moved one. Carried on the
        /// action rather than held by the capture screen because the toast is an
        /// overlay on the app root: it outlives the screen that recorded it, and
        /// it has to disappear with the action when the action is undone.
        let tree: TreeConfirmation?
        /// Nil for a message that only reports something. A failed save has
        /// nothing to reverse, so its toast offers no Undo.
        let undo: (() -> Void)?

        /// Whether this action can be taken back.
        var isUndoable: Bool { undo != nil }
    }

    @Published var current: Action?
    private var history: [Action] = []
    private var dismissTask: Task<Void, Never>?

    func record(_ message: String, tree: TreeConfirmation? = nil, undo: @escaping () -> Void) {
        history.append(Action(message: message, tree: tree, undo: undo))
        showCurrent()
    }

    /// Reports something the user needs to see but cannot reverse — a save the
    /// store refused. It deliberately does not enter the undo history: there is
    /// no inverse operation, and offering one would imply the change happened.
    func report(_ message: String) {
        dismissTask?.cancel()
        current = Action(message: message, tree: nil, undo: nil)
        scheduleDismiss()
    }

    func undo() {
        // Block only on a *visible* failure notice: popping history then would
        // reverse something the user is not looking at. A nil `current` means
        // the toast has simply timed out, which has never stopped an undo and
        // must not start now — the stack's LIFO contract outlives the toast.
        guard current?.isUndoable != false else { return }
        guard let action = history.popLast() else { return }
        dismissTask?.cancel()
        current = nil
        action.undo?()
    }

    private func showCurrent() {
        dismissTask?.cancel()
        current = history.last
        scheduleDismiss()
    }

    private func scheduleDismiss() {
        let task = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(5))
            } catch {
                return // cancelled
            }
            guard !Task.isCancelled else { return }
            self?.current = nil
        }
        dismissTask = task
    }
}
