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
}
