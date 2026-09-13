import SwiftUI

/// A budgeted category's tree either side of the entry that was just logged.
///
/// The toast needs both halves, not just the result: showing only the new state
/// tells the user where the tree stands, while showing the old one first tells
/// them what their tap did. That is the whole reason this exists — logging is
/// the one place in the app where the action and its consequence can meet.
struct TreeConfirmation: Equatable {
    /// The tree as it stands now, with this entry counted.
    let tree: GroveTree
    /// The tree as it stood a moment ago.
    let previous: GroveTree

    /// True when this entry actually moved the tree between states. A log that
    /// lands well inside a comfortable budget leaves this false, and the toast
    /// then shows the tree without performing anything.
    var didChange: Bool { previous.mark != tree.mark }
}

struct UndoToast: View {
    @EnvironmentObject private var undoStack: UndoStack

    /// How far the toast floats above the bottom edge.
    ///
    /// Defaults to clearing the capture screen's pinned keypad-and-Log bar,
    /// which is the only place this used to be shown. A sheet has no such bar,
    /// so the screens presented as one pass `sheetInset` instead and the toast
    /// sits a normal margin off the bottom.
    var bottomInset: CGFloat = CaptureBottomBar.height + CaptureBottomBar.toastGap

    /// Bottom margin for a toast shown inside a presented sheet.
    ///
    /// A sheet needs its own copy of this view at all: the root's overlay is
    /// *behind* anything presented over it, so an archive, a delete or an edit
    /// performed from History recorded a perfectly good undo that the user could
    /// never see or reach, and a save that failed inside the edit sheet reported
    /// the failure to a surface nobody was looking at.
    static let sheetInset: CGFloat = 16

    var body: some View {
        VStack {
            Spacer()
            if let action = undoStack.current {
                HStack(spacing: 12) {
                    if let confirmation = action.tree {
                        ConfirmationTree(confirmation: confirmation)
                            // A fresh view per action, so a second log restarts
                            // the change animation instead of inheriting the
                            // settled state of the log before it.
                            .id(action.id)
                    } else if action.isUndoable {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Theme.accent)
                            .symbolEffect(.bounce, options: .nonRepeating, value: undoStack.current?.id)
                    } else {
                        // Clay, not the sage every other toast uses: this one is
                        // reporting that the thing the user asked for did not
                        // happen, and it must not read as another confirmation.
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Theme.toastClay)
                            .symbolEffect(.bounce, options: .nonRepeating, value: undoStack.current?.id)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(action.message)
                            .lineLimit(1)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.toastText)
                        // Where the category now stands for the period, in the
                        // Budgets screen's own words — "₹40.00 left this week" —
                        // so the consequence is a sentence the user can already
                        // read elsewhere rather than a new phrasing to learn.
                        if let confirmation = action.tree {
                            Text(confirmation.tree.detail)
                                .lineLimit(1)
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(Theme.toastText.opacity(0.72))
                        }
                    }

                    Spacer(minLength: 8)
                    // A failure has no inverse, so it offers no button. Showing
                    // a disabled or dead "Undo" beside it would imply something
                    // had happened that could be taken back.
                    if action.isUndoable {
                        Button("Undo") {
                            undoStack.undo()
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.accent)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.toast, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.hairline))
                .padding(.horizontal, 16)
                // On the home screen this clears the whole pinned bottom bar —
                // keypad and Log pill both — rather than just the pill: an
                // overlapping toast blocked back-to-back logging for its full 5s
                // window, and "Undo" landed squarely on the backspace key.
                .padding(.bottom, bottomInset)
                // Fades in and rises out of the gap it already leaves above the
                // bar — the same 14pt-ish lift the rest of the app enters with.
                // Sliding in from the screen edge instead, as this did, swept
                // the whole toast up across the keypad and the Log pill: for
                // those few frames it covered live controls and, being
                // hit-testable, could swallow the tap aimed at one. Travelling
                // only as far as the clearance means no frame of the entrance
                // ever reaches a key.
                .transition(.opacity.combined(with: .offset(y: CaptureBottomBar.toastGap)))
            }
        }
        .animation(Motion.gentle, value: undoStack.current?.id)
        .allowsHitTesting(undoStack.current != nil)
    }
}

/// The tree beside the confirmation, holding its old state for a beat before
/// easing into the new one.
///
/// The hold is the point: a tree that is simply *drawn* thinned says the
/// category is over target, while a tree the user watches thin says their tap
/// did that. It is a cross-fade and nothing else — no shake, no flash, no red.
/// The copy promises the tree thins rather than dies, and a confirmation that
/// flinched would be the app breaking that promise at the one moment the user is
/// actually looking. A log that changes nothing skips all of it and just stands
/// there, which is most logs.
private struct ConfirmationTree: View {
    let confirmation: TreeConfirmation

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    var body: some View {
        // Nothing to cross-fade from unless the state actually moved, and Reduce
        // Motion gets the answer without the transition.
        let showsNewState = settled || !confirmation.didChange || reduceMotion
        ZStack {
            TreeStateGlyph(state: confirmation.previous.mark, color: confirmation.previous.toastTint)
                .opacity(showsNewState ? 0 : 1)
            TreeStateGlyph(state: confirmation.tree.mark, color: confirmation.tree.toastTint)
                .opacity(showsNewState ? 1 : 0)
        }
        .frame(width: 22, height: 28)
        .accessibilityElement()
        // VoiceOver never sees the drawing, so it gets the category, the state
        // and the same sentence the sighted user reads beside it.
        .accessibilityLabel(confirmation.tree.accessibilityLabel)
        .onAppear {
            guard confirmation.didChange, !reduceMotion else { return }
            // The toast slides in first and the change follows it, so the two
            // movements read as one thought instead of arriving on top of each
            // other. Both are done inside a second of the tap.
            withAnimation(Motion.gentleSlow.delay(0.4)) { settled = true }
        }
    }
}
