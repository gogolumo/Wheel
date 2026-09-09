import XCTest
@testable import WheelCore
@testable import WheelDomain

final class SpatialNavigationControllerTests: XCTestCase {
    func testOnlyOneGestureCanBeActive() throws {
        var controller = SpatialNavigationController()

        _ = try controller.startGesture(triggerType: .capsLock)

        XCTAssertThrowsError(
            try controller.startGesture(triggerType: .rightOption)
        ) { error in
            XCTAssertEqual(
                error as? NavigationControllerError,
                .gestureAlreadyActive
            )
        }
    }

    func testCompletingSessionReleasesActiveSlot() throws {
        var controller = SpatialNavigationController()

        _ = try controller.startGesture(triggerType: .capsLock)
        let completed = try controller.completeGesture(direction: .left)

        XCTAssertNil(controller.activeSession)
        XCTAssertEqual(completed.status, .completed(.left))

        XCTAssertNoThrow(
            try controller.startGesture(triggerType: .rightOption)
        )
    }
}
