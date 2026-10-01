import XCTest
@testable import WheelDomain
@testable import WheelMacOS

final class HorizontalGestureClassifierTests: XCTestCase {
    private let classifier = HorizontalGestureClassifier(
        minimumHorizontalDistance: 80,
        minimumDominanceRatio: 1.5
    )

    func testClassifiesLeftGesture() {
        let direction = classifier.classify(
            PointerDisplacement(horizontal: -120, vertical: 20)
        )

        XCTAssertEqual(direction, .left)
    }

    func testClassifiesRightGesture() {
        let direction = classifier.classify(
            PointerDisplacement(horizontal: 120, vertical: -20)
        )

        XCTAssertEqual(direction, .right)
    }

    func testRejectsMovementBelowDistanceThreshold() {
        let direction = classifier.classify(
            PointerDisplacement(horizontal: 79.9, vertical: 0)
        )

        XCTAssertEqual(direction, .none)
    }

    func testRejectsVerticalDominantMovement() {
        let direction = classifier.classify(
            PointerDisplacement(horizontal: 100, vertical: 80)
        )

        XCTAssertEqual(direction, .none)
    }

    func testAcceptsExactThresholds() {
        let direction = classifier.classify(
            PointerDisplacement(horizontal: -90, vertical: 60)
        )

        XCTAssertEqual(direction, .left)
    }
}
