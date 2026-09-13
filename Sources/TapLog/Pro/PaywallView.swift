import SwiftUI
import SwiftData

/// The one screen that asks for money.
///
/// It is built out of the same trees the rest of the app is built out of, and it
/// arrives only at the two moments someone has just tried to do the thing it
/// sells — another tree, or the month view. Nobody is shown this on launch, and
/// nobody is shown it twice for the same tap.
///
/// It says what it costs, once, and it says what happens if you say no: the app
/// keeps working. An expense tracker that nags is an expense tracker people
/// delete.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    /// Read here rather than passed in: this sheet has three call sites, all of
    /// them already inside the container, and the evidence belongs to the screen
    /// that shows it rather than to whichever screen happened to open it.
    @Query(filter: #Predicate<Entry> { !$0.isArchived && !$0.isPending })
    private var entries: [Entry]

    var store: ProStore = .shared

    /// What the user was reaching for when this appeared. Only the headline
    /// changes — the offer is the same either way.
    let reason: Reason

    enum Reason {
        case anotherTree
        case monthlyRecap

        var headline: String {
            switch self {
            case .anotherTree: "Grow a whole grove"
            case .monthlyRecap: "See the longer view"
            }
        }

        var subhead: String {
            switch self {
            case .anotherTree:
                "Your grove is full. TapLog Pro lets you plant a target for every category you care about."
            case .monthlyRecap:
                "Your weekly recap is free forever. Pro adds the monthly one, for the patterns a week is too short to show."
            }
        }
    }

    private var priceText: String {
        store.product?.displayPrice ?? "—"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    let evidence = PaywallEvidence.make(entries: entries)
                    if evidence.isWorthShowing {
                        record(evidence)
                    } else {
                        grove
                    }
                    headline
                    included
                    if let failure = store.failureMessage {
                        Text(failure)
                            .font(.footnote)
                            .foregroundStyle(Theme.clay)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .safeAreaInset(edge: .bottom) {
                purchaseArea
            }
            .navigationTitle("TapLog Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
            .task {
                // The one place the price is needed, and so the one place worth
                // talking to the App Store from.
                await store.loadProduct()
            }
            .onChange(of: store.isPro) { _, isPro in
                // The moment it unlocks, get out of the way — the user came here
                // to do something else and this screen is no longer between them
                // and it.
                if isPro { dismiss() }
            }
        }
        .tint(Theme.accent)
    }

    /// The user's own record, in place of the decorative grove. Shown only once
    /// there is enough of it to mean something (`PaywallEvidence.isWorthShowing`).
    private func record(_ evidence: PaywallEvidence) -> some View {
        VStack(spacing: 6) {
            Text(evidence.summaryLine)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Your record so far, kept on this phone.")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your record so far: \(evidence.summaryLine), kept on this phone.")
    }

    /// The grove, as a promise rather than a diagram: one tree the user already
    /// has, and the ones they don't yet.
    private var grove: some View {
        HStack(alignment: .bottom, spacing: 14) {
            TreeMark(state: .growing, color: Theme.accent)
                .frame(width: 54, height: 54)
            TreeMark(state: .seedling, color: Theme.accent)
                .frame(width: 40, height: 40)
            TreeMark(state: .growing, color: Theme.accent)
                .frame(width: 48, height: 48)
            TreeMark(state: .sprout, color: Theme.accent)
                .frame(width: 40, height: 40)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
        .accessibilityHidden(true)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(reason.headline)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(reason.subhead)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var included: some View {
        VStack(alignment: .leading, spacing: 14) {
            row("A target for every category", "leaf")
            row("The monthly recap, alongside the weekly one", "chart.bar")
            row("One payment, yours for good", "checkmark.seal")
        }
    }

    private func row(_ text: String, _ symbol: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var purchaseArea: some View {
        VStack(spacing: 12) {
            Button {
                Task { await store.purchase() }
            } label: {
                Group {
                    if store.isWorking {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Unlock for \(priceText)")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.accent, in: Capsule())
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(store.product == nil || store.isWorking)
            .opacity(store.product == nil ? 0.5 : 1)

            Button("Restore purchase") {
                Task { await store.restore() }
            }
            .font(.footnote)
            .foregroundStyle(Theme.textSecondary)
            .disabled(store.isWorking)

            Text("Everything you already use stays free.")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Theme.background)
    }
}
