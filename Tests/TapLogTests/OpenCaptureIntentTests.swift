import XCTest
@testable import TapLog

/// Regression tests for the durable pending-activation pattern used by
/// `OpenCaptureIntent` to route the UI into the capture screen.
final class OpenCaptureIntentTests: XCTestCase {
    private let suiteName = "test.OpenCaptureIntent"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
        defaults.set(false, forKey: "intent.pendingCaptureActive")
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - .none when nothing pending

    func testConsumeReturnsNoneWhenNothingPending() {
        let result = OpenCaptureIntent.consumePendingActivation(defaults: defaults)
        if case .none = result {
            // expected
        } else {
            XCTFail("expected .none when nothing pending, got \(result)")
        }
    }

    // MARK: - .open with prefill

    func testConsumeReturnsOpenWithPrefill() {
        OpenCaptureIntent.writePendingActivation(
            amount: "42.50",
            defaults: defaults
        )

        let result = OpenCaptureIntent.consumePendingActivation(defaults: defaults)
        if case .open(let prefill) = result {
            XCTAssertEqual(prefill?.amountText, "42.50")
            XCTAssertNil(prefill?.categoryQuery)
            XCTAssertNil(prefill?.note)
        } else {
            XCTFail("expected .open, got \(result)")
        }
    }

    func testConsumeReturnsOpenWithAllParams() {
        OpenCaptureIntent.writePendingActivation(
            amount: "10",
            category: "chai",
            note: "morning",
            defaults: defaults
        )

        let result = OpenCaptureIntent.consumePendingActivation(defaults: defaults)
        if case .open(let prefill) = result {
            XCTAssertEqual(prefill?.amountText, "10")
            XCTAssertEqual(prefill?.categoryQuery, "chai")
            XCTAssertEqual(prefill?.note, "morning")
        } else {
            XCTFail("expected .open, got \(result)")
        }
    }

    // MARK: - .open with nil prefill (parameterless invocation)

    func testParameterlessInvocationReturnsOpenWithNilPrefill() {
        OpenCaptureIntent.writePendingActivation(defaults: defaults)

        let result = OpenCaptureIntent.consumePendingActivation(defaults: defaults)
        if case .open(let prefill) = result {
            XCTAssertNil(prefill, "parameterless invocation should have nil prefill")
        } else {
            XCTFail("expected .open, got \(result)")
        }
    }

    // MARK: - Idempotency

    func testConsumeIsIdempotent() {
        OpenCaptureIntent.writePendingActivation(amount: "5", defaults: defaults)

        let first = OpenCaptureIntent.consumePendingActivation(defaults: defaults)
        if case .open = first {} else { XCTFail("expected .open") }

        let second = OpenCaptureIntent.consumePendingActivation(defaults: defaults)
        if case .none = second {} else {
            XCTFail("second consume must return .none, got \(second)")
        }
    }

    func testWriteResetsPreviouslyClearedFlag() {
        OpenCaptureIntent.writePendingActivation(amount: "1", defaults: defaults)
        _ = OpenCaptureIntent.consumePendingActivation(defaults: defaults)

        OpenCaptureIntent.writePendingActivation(amount: "2", defaults: defaults)
        let result = OpenCaptureIntent.consumePendingActivation(defaults: defaults)
        if case .open(let prefill) = result {
            XCTAssertEqual(prefill?.amountText, "2")
        } else {
            XCTFail("expected .open after re-write")
        }
    }
}
