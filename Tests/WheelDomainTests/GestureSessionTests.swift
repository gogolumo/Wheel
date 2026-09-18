import XCTest
@testable import WheelDomain

final class GestureSessionTests: XCTestCase {
    func testSessionCompletesOnlyOnce() {
        var session = GestureSession(triggerType: .capsLock)

        XCTAssertTrue(session.complete(direction: .left))
        XCTAssertFalse(session.complete(direction: .right))
        XCTAssertFalse(session.cancel())
        XCTAssertEqual(session.status, .completed(.left))
    }

    func testSessionCanCancelFromTracking() {
        var session = GestureSession(triggerType: .rightOption)

        XCTAssertTrue(session.cancel())
        XCTAssertEqual(session.status, .cancelled)
    }

    func testCancelledSessionRejectsEveryLaterTerminalTransition() {
        var session = GestureSession(triggerType: .capsLock)

        XCTAssertTrue(session.cancel())
        XCTAssertFalse(session.cancel())
        XCTAssertFalse(session.complete(direction: .left))
        XCTAssertFalse(session.complete(direction: .right))
        XCTAssertFalse(session.complete(direction: .none))
        XCTAssertEqual(session.status, .cancelled)
    }

    func testCompletedSessionKeepsOriginalDirectionAfterDuplicateCallbacks() {
        for direction in [Direction.left, .right, .none] {
            var session = GestureSession(triggerType: .rightOption)

            XCTAssertTrue(session.complete(direction: direction))
            XCTAssertFalse(session.cancel())

            for duplicateDirection in [Direction.left, .right, .none] {
                XCTAssertFalse(session.complete(direction: duplicateDirection))
            }

            XCTAssertEqual(session.status, .completed(direction))
        }
    }
}
