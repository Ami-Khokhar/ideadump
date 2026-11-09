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
        // and the keypad-plus-Log bar is 326pt of that. 398 is the number this
        // rule has to produce; hardcoding it is what fails if the bar stops
        // being subtracted.
        let visible = CaptureFit.visibleHeight(
            containerHeight: 874 - 116 - 34,
            barHeight: CaptureBottomBar.height
        )
        XCTAssertEqual(visible, 398, accuracy: 0.5)
    }

    func testVisibleHeightFollowsTheContainerAndNotTheBar() {
        let one = CaptureFit.visibleHeight(containerHeight: 500, barHeight: 300)
        let two = CaptureFit.visibleHeight(containerHeight: 600, barHeight: 300)
        XCTAssertEqual(two - one, 100, accuracy: 0.5, "growing the container must grow the visible height one-for-one")

        let three = CaptureFit.visibleHeight(containerHeight: 500, barHeight: 380)
        XCTAssertEqual(one - three, 80, accuracy: 0.5, "a taller bar must take exactly its own height away")
    }

    func testVisibleHeightNeverGoesNegative() {
        XCTAssertEqual(CaptureFit.visibleHeight(containerHeight: 200, barHeight: 326), 0)
    }

    func testContentMinimumAdvancesWithTheAmountRow() {
        // The floors below the amount are fixed, so a taller amount row must add
        // exactly its own growth and nothing else.
        let short = CaptureFit.contentMinHeight(amountHeroHeight: 132)
        let tall = CaptureFit.contentMinHeight(amountHeroHeight: 190)
        XCTAssertEqual(tall - short, 58, accuracy: 0.5)
        XCTAssertGreaterThan(short, 132, "the floors below the amount are part of the stack")
    }
}
