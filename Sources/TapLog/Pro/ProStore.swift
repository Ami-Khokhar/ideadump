import Foundation
import StoreKit

/// The one thing TapLog sells: a single non-consumable that unlocks the app for
/// good. No subscription, no tiers, no consumables — an expense tracker that
/// charges rent every month is a worse joke than it is a business model.
enum ProProduct {
    static let lifetimeID = "dev.amteshwar.taplog.pro.lifetime"
}

/// What the paywall shows for the one product. A plain value, so a test can
/// stand in for a store answer without constructing a StoreKit product.
struct ProOffer: Equatable {
    let displayPrice: String
}

/// What a purchase attempt did, in plain terms. `ignored` is a result whose
/// signature did not verify: it is not evidence of a purchase, so nothing is
/// shown and nothing changes.
enum ProPurchaseOutcome: Equatable {
    case unlocked
    case cancelled
    case pending
    case ignored
    case failed(String)
}

/// Whether a verified transaction grants Pro. Pure, so the two rules that guard
/// the entitlement — the transaction is for the product we sell, and it has not
/// been revoked — are testable without a real StoreKit transaction.
enum ProEntitlement {
    static func grantsPro(productID: String, revocationDate: Date?) -> Bool {
        productID == ProProduct.lifetimeID && revocationDate == nil
    }
}

/// The StoreKit boundary. The real implementation talks to the App Store; a test
/// replaces it with scripted answers, which is what makes the loading, retry,
/// purchase and restore paths testable at all.
@MainActor
protocol ProStoreBackend {
    func loadOffer() async -> ProOffer?
    func purchase() async -> ProPurchaseOutcome
    func isEntitled() async -> Bool
    func sync() async throws
}

/// The real backend. StoreKit is the authority for all four answers.
@MainActor
final class StoreKitBackend: ProStoreBackend {
    private var product: Product?

    func loadOffer() async -> ProOffer? {
        guard let product = try? await Product.products(for: [ProProduct.lifetimeID]).first else {
            self.product = nil
            return nil
        }
        self.product = product
        return ProOffer(displayPrice: product.displayPrice)
    }

    func purchase() async -> ProPurchaseOutcome {
        guard let product else {
            return .failed("The App Store isn't reachable right now.")
        }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    // An unverified result is not evidence of a purchase.
                    return .ignored
                }
                await transaction.finish()
                return .unlocked
            case .userCancelled:
                // Backing out is an answer, not an error. Saying anything here
                // would be the app arguing with someone who just said no.
                return .cancelled
            case .pending:
                // Ask to Buy and similar. The entitlement arrives through
                // `Transaction.updates` if and when it is approved.
                return .pending
            @unknown default:
                return .cancelled
            }
        } catch {
            return .failed("That didn't go through. You have not been charged.")
        }
    }

    func isEntitled() async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if ProEntitlement.grantsPro(
                productID: transaction.productID,
                revocationDate: transaction.revocationDate
            ) {
                return true
            }
        }
        return false
    }

    func sync() async throws {
        try await AppStore.sync()
    }
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
    private(set) var offer: ProOffer?

    /// Set when a purchase or restore fails in a way worth telling the user
    /// about. Cancellation is not a failure and never lands here.
    private(set) var failureMessage: String?

    private(set) var isWorking = false

    /// Product loading is its own state so the paywall can tell "still asking"
    /// from "the store said no", and offer a retry only for the second.
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case unavailable
    }

    private(set) var loadState: LoadState = .idle

    private let backend: ProStoreBackend
    private var updatesTask: Task<Void, Never>?

    init(backend: ProStoreBackend? = nil) {
        self.backend = backend ?? StoreKitBackend()
    }

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

    /// Fetches the product. Called by the paywall as it appears, and again from
    /// its retry control — so a first failure is not the paywall's last word.
    func loadProduct() async {
        guard loadState != .loading else { return }
        loadState = .loading
        if let offer = await backend.loadOffer() {
            self.offer = offer
            loadState = .loaded
        } else {
            offer = nil
            loadState = .unavailable
        }
    }

    /// Recomputes `isPro` from what StoreKit currently vouches for.
    func refresh() async {
        isPro = await backend.isEntitled()
    }

    func purchase() async {
        guard offer != nil else {
            failureMessage = "The App Store isn't reachable right now."
            return
        }
        failureMessage = nil
        isWorking = true
        defer { isWorking = false }

        switch await backend.purchase() {
        case .unlocked:
            await refresh()
        case .cancelled, .pending, .ignored:
            break
        case .failed(let message):
            failureMessage = message
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
            try await backend.sync()
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
