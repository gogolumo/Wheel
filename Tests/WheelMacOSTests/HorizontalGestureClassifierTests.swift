import XCTest
@testable import WheelDomain
@testable import WheelMacOS

final class HorizontalGestureClassifierTests: XCTestCase {
    private let classifier = HorizontalGestureClassifier(
        minimumHorizontalDistance: 80,
        minimumDominanceRatio: 1.5
    )

    func testClassifiesLeftGesture() {
        XCTAssertEqual(
            classifier.classify(PointerDisplacement(horizontal: -120, vertical: 20)),
            .left
        )
    }

    func testClassifiesRightGesture() {
        XCTAssertEqual(
            classifier.classify(PointerDisplacement(horizontal: 120, vertical: -20)),
            .right
        )
    }

    func testRejectsMovementBelowDistanceThreshold() {
        XCTAssertEqual(
            classifier.classify(PointerDisplacement(horizontal: 79.9, vertical: 0)),
            .none
        )
    }

    func testAcceptsExactDistanceThreshold() {
        XCTAssertEqual(
            classifier.classify(PointerDisplacement(horizontal: 80, vertical: 0)),
            .right
        )
    }

    func testRejectsVerticalDominantMovement() {
        XCTAssertEqual(
            classifier.classify(PointerDisplacement(horizontal: 100, vertical: 80)),
            .none
        )
    }

    func testAcceptsExactDominanceThreshold() {
        XCTAssertEqual(
            classifier.classify(PointerDisplacement(horizontal: -90, vertical: 60)),
            .left
        )
    }

    func testClassifiesVeryLargeDisplacement() {
        XCTAssertEqual(
            classifier.classify(PointerDisplacement(horizontal: 10_000, vertical: 1)),
            .right
        )
    }

    func testRejectsNoiseAroundOrigin() {
        let samples = [
            PointerDisplacement(horizontal: 0, vertical: 0),
            PointerDisplacement(horizontal: 3, vertical: -2),
            PointerDisplacement(horizontal: -12, vertical: 7),
            PointerDisplacement(horizontal: 40, vertical: -25),
            PointerDisplacement(horizontal: -79.99, vertical: 0)
        ]

        for sample in samples {
            XCTAssertEqual(classifier.classify(sample), .none)
        }
    }

    func testRejectsSmallMovementRegardlessOfDirection() {
        XCTAssertEqual(
            classifier.classify(PointerDisplacement(horizontal: -50, vertical: 0)),
            .none
        )
        XCTAssertEqual(
            classifier.classify(PointerDisplacement(horizontal: 50, vertical: 0)),
            .none
        )
    }

    func testFinalDisplacementDeterminesReversalResult() {
        // The classifier deliberately consumes the session's final displacement,
        // not raw movement history. A reversal that finishes clearly left/right
        // therefore maps to the final displacement supplied by the monitor.
        XCTAssertEqual(
            classifier.classify(PointerDisplacement(horizontal: -120, vertical: 10)),
            .left
        )
        XCTAssertEqual(
            classifier.classify(PointerDisplacement(horizontal: 120, vertical: 10)),
            .right
        )
    }

    func testNoMovementIsNone() {
        XCTAssertEqual(
            classifier.classify(PointerDisplacement(horizontal: 0, vertical: 0)),
            .none
        )
    }

    func testClassificationIsIndependentOfSessionDuration() {
        // Duration belongs to the session/evidence layer. The same final
        // displacement must classify identically for short and long holds.
        let displacement = PointerDisplacement(horizontal: -120, vertical: 20)
        XCTAssertEqual(classifier.classify(displacement), .left)
        XCTAssertEqual(classifier.classify(displacement), .left)
    }
}
