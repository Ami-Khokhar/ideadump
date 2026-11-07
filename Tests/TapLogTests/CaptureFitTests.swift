import XCTest
@testable import TapLog

/// Pins the fill-versus-scroll rule for the capture stack. The bug this guards
/// against is measuring the whole screen instead of the region above the
/// keypad: the fill candidate then always "fits" and the tile row is drawn
/// behind the opaque bar.
final class CaptureFitTests: XCTestCase {
    func testContentShorterThanVisibleHeightDoesNotScroll() {
        XCTAssertFalse(CaptureFit.usesScroll(visibleHeight: 500, contentMinHeight: 461))
    }

    func testContentTallerThanVisibleHeightScrolls() {
        XCTAssertTrue(CaptureFit.usesScroll(visibleHeight: 500, contentMinHeight: 501))
    }

    func testContentEqualToVisibleHeightDoesNotScroll() {
        XCTAssertFalse(CaptureFit.usesScroll(visibleHeight: 500, contentMinHeight: 500))
    }

    func testVisibleHeightExcludesThePinnedBottomBar() {
        // iPhone 17 portrait, measured on the simulator: an 874pt screen with
        // 116pt above the content and 34pt below it leaves a 724pt container,
        // and the keypad-plus-Log bar is 326pt of that.
        let container: CGFloat = 874 - 116 - 34
        let visible = CaptureFit.visibleHeight(
            containerHeight: container,
            barHeight: CaptureBottomBar.height
        )

        XCTAssertEqual(container, 724)
        XCTAssertEqual(CaptureBottomBar.height, 326)
        XCTAssertEqual(visible, 398)
        XCTAssertEqual(visible, 874 - 116 - 34 - CaptureBottomBar.height)
        // The bar is not part of what the user can see.
        XCTAssertLessThan(visible, container)
    }

    func testVisibleHeightNeverGoesNegative() {
        XCTAssertEqual(CaptureFit.visibleHeight(containerHeight: 200, barHeight: 326), 0)
    }

    func testContentMinimumAddsTheFlexingFloorsToTheAmountRow() {
        // 48 above + 36 below + 28 category line + 84 tile row.
        XCTAssertEqual(CaptureFit.contentMinHeight(amountHeroHeight: 132), 132 + 196)
        XCTAssertEqual(CaptureFit.contentMinHeight(amountHeroHeight: 190), 190 + 196)
    }
}
