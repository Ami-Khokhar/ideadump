import XCTest
@testable import TapLog

/// The paywall's loading, retry, purchase and restore paths, driven through a
/// scripted store. StoreKit stays the real authority in the app; these tests
/// replace only the boundary, so every branch the paywall shows is exercised.
@MainActor
final class ProStoreTests: XCTestCase {

    private final class FakeBackend: ProStoreBackend {
        var offer: ProOffer?
        var purchaseOutcome: ProPurchaseOutcome = .cancelled
        var entitled = false
        var syncError: Error?
        var loadCount = 0
        var purchaseCount = 0
        var syncCount = 0

        func loadOffer() async -> ProOffer? {
            loadCount += 1
            return offer
        }

        func purchase() async -> ProPurchaseOutcome {
            purchaseCount += 1
            return purchaseOutcome
        }

        func isEntitled() async -> Bool { entitled }

        func sync() async throws {
            syncCount += 1
            if let syncError { throw syncError }
        }
    }

    private func makeStore(_ backend: FakeBackend) -> ProStore {
        ProStore(backend: backend)
    }

    // MARK: - Product loading and retry

    func testAFailedLoadIsUnavailableAndCanBeRetriedToSuccess() async {
        let backend = FakeBackend()
        backend.offer = nil
        let store = makeStore(backend)

        await store.loadProduct()
        XCTAssertEqual(store.loadState, .unavailable)
        XCTAssertNil(store.offer)

        backend.offer = ProOffer(displayPrice: "₹199")
        await store.loadProduct()
        XCTAssertEqual(store.loadState, .loaded)
        XCTAssertEqual(store.offer, ProOffer(displayPrice: "₹199"))
        XCTAssertEqual(backend.loadCount, 2, "the retry must ask the store again")
    }

    func testAnUnavailableProductIsNotPurchasable() async {
        let backend = FakeBackend()
        backend.offer = nil
        let store = makeStore(backend)
        await store.loadProduct()

        await store.purchase()

        XCTAssertFalse(store.isPro)
        XCTAssertEqual(backend.purchaseCount, 0, "no product means no purchase attempt")
        XCTAssertNotNil(store.failureMessage)
    }

    // MARK: - Purchase outcomes

    func testAVerifiedPurchaseUnlocks() async {
        let backend = FakeBackend()
        backend.offer = ProOffer(displayPrice: "₹199")
        backend.purchaseOutcome = .unlocked
        backend.entitled = true
        let store = makeStore(backend)
        await store.loadProduct()

        await store.purchase()

        XCTAssertTrue(store.isPro)
        XCTAssertNil(store.failureMessage)
    }

    func testACancelledPurchaseIsSilent() async {
        let backend = FakeBackend()
        backend.offer = ProOffer(displayPrice: "₹199")
        backend.purchaseOutcome = .cancelled
        let store = makeStore(backend)
        await store.loadProduct()

        await store.purchase()

        XCTAssertFalse(store.isPro)
        XCTAssertNil(store.failureMessage, "backing out is an answer, not an error")
    }

    func testAnIgnoredPurchaseDoesNotUnlock() async {
        let backend = FakeBackend()
        backend.offer = ProOffer(displayPrice: "₹199")
        backend.purchaseOutcome = .ignored
        backend.entitled = true
        let store = makeStore(backend)
        await store.loadProduct()

        await store.purchase()

        XCTAssertFalse(store.isPro, "an unverified transaction is not evidence of a purchase")
        XCTAssertNil(store.failureMessage)
    }

    // MARK: - Restore

    func testARestoreThatFindsAPurchaseUnlocks() async {
        let backend = FakeBackend()
        backend.entitled = true
        let store = makeStore(backend)

        await store.restore()

        XCTAssertTrue(store.isPro)
        XCTAssertNil(store.failureMessage)
        XCTAssertEqual(backend.syncCount, 1)
    }

    func testARestoreThatFindsNothingSaysSo() async {
        let backend = FakeBackend()
        backend.entitled = false
        let store = makeStore(backend)

        await store.restore()

        XCTAssertFalse(store.isPro)
        XCTAssertEqual(store.failureMessage, "No previous purchase found on this Apple Account.")
    }

    func testARestoreErrorIsReported() async {
        struct Offline: Error {}
        let backend = FakeBackend()
        backend.syncError = Offline()
        let store = makeStore(backend)

        await store.restore()

        XCTAssertFalse(store.isPro)
        XCTAssertEqual(store.failureMessage, "Couldn't reach the App Store to restore.")
    }

    // MARK: - Entitlement policy

    func testTheEntitlementNeedsTheExpectedProductAndNoRevocation() {
        XCTAssertTrue(ProEntitlement.grantsPro(productID: ProProduct.lifetimeID, revocationDate: nil))
        XCTAssertFalse(ProEntitlement.grantsPro(productID: ProProduct.lifetimeID, revocationDate: .now))
        XCTAssertFalse(ProEntitlement.grantsPro(productID: "dev.amteshwar.taplog.pro.other", revocationDate: nil))
    }
}
