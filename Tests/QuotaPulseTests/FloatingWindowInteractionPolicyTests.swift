import XCTest
@testable import QuotaPulse

final class FloatingWindowInteractionPolicyTests: XCTestCase {
    func testKeepsCompactStateWhilePrimaryButtonIsPressedOutsideWindow() {
        XCTAssertEqual(
            FloatingWindowInteractionPolicy.targetCompactState(
                isCompact: true,
                pointerIsInside: false,
                isPrimaryButtonPressed: true
            ),
            true
        )
    }

    func testKeepsExpandedStateWhilePrimaryButtonIsPressedOutsideWindow() {
        XCTAssertEqual(
            FloatingWindowInteractionPolicy.targetCompactState(
                isCompact: false,
                pointerIsInside: false,
                isPrimaryButtonPressed: true
            ),
            false
        )
    }

    func testResumesHoverStateAfterPrimaryButtonIsReleased() {
        XCTAssertEqual(
            FloatingWindowInteractionPolicy.targetCompactState(
                isCompact: false,
                pointerIsInside: false,
                isPrimaryButtonPressed: false
            ),
            true
        )
        XCTAssertEqual(
            FloatingWindowInteractionPolicy.targetCompactState(
                isCompact: true,
                pointerIsInside: true,
                isPrimaryButtonPressed: false
            ),
            false
        )
    }

    func testDefaultPlacementKeepsExpandedWindowInsideVisibleFrameAtTopRight() {
        let visibleFrame = CGRect(x: 100, y: 50, width: 1_440, height: 900)
        let windowSize = CGSize(width: 356, height: 444)

        XCTAssertEqual(
            FloatingWindowPlacementPolicy.defaultOrigin(
                visibleFrame: visibleFrame,
                windowSize: windowSize
            ),
            CGPoint(x: 1_166, y: 488)
        )
    }

    func testRequestsRecoveryWhenWindowHasLessThanMinimumVisibleArea() {
        XCTAssertTrue(
            FloatingWindowPlacementPolicy.shouldRecover(
                windowFrame: CGRect(x: 1_520, y: 900, width: 356, height: 444),
                visibleFrames: [CGRect(x: 0, y: 0, width: 1_540, height: 900)]
            )
        )
    }

    func testKeepsWindowAtEdgeWhenItRetainsMinimumVisibleArea() {
        XCTAssertFalse(
            FloatingWindowPlacementPolicy.shouldRecover(
                windowFrame: CGRect(x: 1_508, y: 868, width: 356, height: 444),
                visibleFrames: [CGRect(x: 0, y: 0, width: 1_540, height: 900)]
            )
        )
    }
}
