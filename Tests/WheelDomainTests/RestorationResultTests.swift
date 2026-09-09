import XCTest
@testable import WheelDomain

final class RestorationResultTests: XCTestCase {
    func testOnlySuccessAndPartialAllowPositionChange() {
        let allowed: [RestorationStatus] = [.success, .partial]
        let blocked: [RestorationStatus] = [
            .failed,
            .cancelled,
            .unavailable,
            .permissionDenied
        ]

        for status in allowed {
            XCTAssertTrue(
                RestorationResult(status: status, depth: .application)
                    .allowsPositionChange
            )
        }

        for status in blocked {
            XCTAssertFalse(
                RestorationResult(status: status, depth: .none)
                    .allowsPositionChange
            )
        }
    }
}
