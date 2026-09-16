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

    func testRestorationDepthOrderingMatchesFallbackProgression() {
        let depths: [RestorationDepth] = [.none, .application, .window, .semantic]

        XCTAssertEqual(depths.map(\.rawValue), [0, 1, 2, 3])
        XCTAssertTrue(RestorationDepth.none < .application)
        XCTAssertTrue(RestorationDepth.application < .window)
        XCTAssertTrue(RestorationDepth.window < .semantic)
    }

    func testEveryNonSuccessStatusRejectsPositionChangeAtEveryDepth() {
        let blocked: [RestorationStatus] = [
            .failed,
            .cancelled,
            .unavailable,
            .permissionDenied
        ]
        let depths: [RestorationDepth] = [.none, .application, .window, .semantic]

        for status in blocked {
            for depth in depths {
                XCTAssertFalse(
                    RestorationResult(status: status, depth: depth)
                        .allowsPositionChange,
                    "\(status) at \(depth) must never advance history position"
                )
            }
        }
    }
}
