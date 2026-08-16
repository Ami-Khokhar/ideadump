import SwiftUI

/// Records inverse operations for every mutation and exposes the most recent one as a
/// toast that auto-dismisses after 5 seconds.
@MainActor
final class UndoStack: ObservableObject {
    struct Action: Identifiable {
        let id = UUID()
        let message: String
        let undo: () -> Void
    }

    @Published var current: Action?
    private var history: [Action] = []
    private var dismissTask: Task<Void, Never>?

    func record(_ message: String, undo: @escaping () -> Void) {
        history.append(Action(message: message, undo: undo))
        showCurrent()
    }

    func undo() {
        guard let action = history.popLast() else { return }
        dismissTask?.cancel()
        current = nil
        action.undo()
    }

    private func showCurrent() {
        dismissTask?.cancel()
        current = history.last
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
