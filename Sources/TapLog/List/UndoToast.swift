import SwiftUI

struct UndoToast: View {
    @EnvironmentObject private var undoStack: UndoStack

    var body: some View {
        VStack {
            Spacer()
            if let action = undoStack.current {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                        .symbolEffect(.bounce, options: .nonRepeating, value: undoStack.current?.id)
                    Text(action.message)
                        .lineLimit(1)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.toastText)
                    Spacer(minLength: 8)
                    Button("Undo") {
                        undoStack.undo()
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.accent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.toast, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.hairline))
                .padding(.horizontal, 16)
                // Clears the home screen's whole pinned bottom bar — keypad and
                // Log pill both — rather than just the pill: an overlapping
                // toast blocked back-to-back logging for its full 5s window,
                // and "Undo" landed squarely on the backspace key.
                .padding(.bottom, CaptureBottomBar.height + 10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.gentle, value: undoStack.current?.id)
        .allowsHitTesting(undoStack.current != nil)
    }
}
