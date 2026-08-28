import Foundation
import StoreKit

/// The one thing TapLog sells: a single non-consumable that unlocks the app for
/// good. No subscription, no tiers, no consumables — an expense tracker that
/// charges rent every month is a worse joke than it is a business model.
enum ProProduct {
    static let lifetimeID = "dev.amteshwar.taplog.pro.lifetime"
}

/// Owns the Pro entitlement: what StoreKit says the user has, and the two
/// operations (buy, restore) that can change it.
///
/// `isPro` is derived from `Transaction.currentEntitlements` and never written
/// by the UI, so there is exactly one source of truth for whether the app is
/// unlocked. It is also deliberately *not* persisted to UserDefaults: a flag in
/// defaults is a thing that can drift from the receipt, and the drift always
/// resolves in a direction that annoys somebody — either a payer locked out or a
/// non-payer let in.
@MainActor
@Observable
final class ProStore {

    static let shared = ProStore()

    /// Whether the app is unlocked. Derived from StoreKit, never set by a view.
    private(set) var isPro = false

    /// The product, once the store has answered. Nil while loading, and stays
    /// nil if the lookup fails — the paywall reads this to decide whether it can
    /// show a real price or has to say the store is unreachable.
    private(set) var product: Product?

    /// Set when a purchase or restore fails in a way worth telling the user
    /// about. Cancellation is not a failure and never lands here.
    private(set) var failureMessage: String?

    private(set) var isWorking = false

    private var updatesTask: Task<Void, Never>?

    /// Begins listening for entitlement changes and reads the current one.
    ///
    /// The `Transaction.updates` listener starts before the first entitlement
    /// check, not after: a purchase that completes elsewhere — another device,
    /// an Ask to Buy approval, an interrupted purchase finishing late — arrives
    /// through that stream, and a gap between the check and the listener is a
    /// gap where a real purchase is silently dropped.
    ///
    /// Deliberately does *not* fetch the product. `Product.products` talks to
    /// the App Store, and on a device with no Apple Account signed in that puts
    /// a "Sign in to Apple Account" dialog on screen at launch — a toll
    /// collected before the app has done anything, on someone who may never open
    /// the paywall at all. Reading the entitlement is local and prompts nobody,
    /// so that is all launch does; the price is fetched when the paywall that
    /// needs it appears.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                await self.apply(update)
            }
        }
        Task { await refresh() }
    }

    /// Fetches the product. Called by the paywall as it appears, never at launch.
    func loadProduct() async {
        guard product == nil else { return }
        do {
            product = try await Product.products(for: [ProProduct.lifetimeID]).first
        } catch {
            product = nil
        }
    }

    /// Recomputes `isPro` from what StoreKit currently vouches for.
    func refresh() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == ProProduct.lifetimeID else { continue }
            guard transaction.revocationDate == nil else { continue }
            entitled = true
        }
        isPro = entitled
    }

    func purchase() async {
        guard let product else {
            failureMessage = "The App Store isn't reachable right now."
            return
        }
        failureMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                await apply(verification)
            case .userCancelled:
                // Backing out is an answer, not an error. Saying anything here
                // would be the app arguing with someone who just said no.
                break
            case .pending:
                // Ask to Buy and similar. The entitlement will arrive through
                // `Transaction.updates` if and when it is approved.
                break
            @unknown default:
                break
            }
        } catch {
            failureMessage = "That didn't go through. You have not been charged."
        }
    }

    /// Restores a purchase made on another device or before a reinstall.
    ///
    /// Refreshes from `currentEntitlements` after syncing, so a restore that
    /// finds nothing says so instead of leaving the user staring at an unchanged
    /// screen wondering whether it worked.
    func restore() async {
        failureMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            try await AppStore.sync()
            await refresh()
            if !isPro {
                failureMessage = "No previous purchase found on this Apple Account."
            }
        } catch {
            failureMessage = "Couldn't reach the App Store to restore."
        }
    }

    /// Applies a verified transaction and finishes it.
    ///
    /// An unverified result is ignored rather than trusted: the whole point of
    /// the signature is that a transaction which fails it is not evidence of
    /// anything.
    private func apply(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await refresh()
        await transaction.finish()
    }
}
