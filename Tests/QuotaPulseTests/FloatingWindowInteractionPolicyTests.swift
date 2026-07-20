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
}
