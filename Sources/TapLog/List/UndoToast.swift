import SwiftUI

struct UndoToast: View {
    @EnvironmentObject private var undoStack: UndoStack

    var body: some View {
        VStack {
            Spacer()
            if let action = undoStack.current {
                HStack(spacing: 12) {
                    Text(action.message)
                        .lineLimit(1)
                        .font(.subheadline.weight(.medium))
                    Spacer(minLength: 8)
                    Button("Undo") {
                        undoStack.undo()
                    }
                    .font(.subheadline.weight(.bold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.quaternary))
                .shadow(radius: 8, y: 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: undoStack.current?.id)
        .allowsHitTesting(undoStack.current != nil)
    }
}
