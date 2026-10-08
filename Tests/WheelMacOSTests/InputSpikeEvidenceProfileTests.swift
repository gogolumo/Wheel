import XCTest
@testable import WheelMacOS

final class InputSpikeEvidenceProfileTests: XCTestCase {
    func testSpike001FinalProfileMatchesRecordedAcceptanceGate() {
        let profile = InputSpikeEvidenceProfile.spike001Final

        XCTAssertEqual(profile.requiredTriggers, ["capsLock", "rightOption"])
        XCTAssertEqual(
            profile.minimumRunCountByTrigger,
            ["capsLock": 2, "rightOption": 2]
        )
        XCTAssertEqual(
            profile.requiredRuns,
            [
                "caps-lock-built-in": "capsLock",
                "caps-lock-external": "capsLock",
                "right-option-built-in": "rightOption",
                "right-option-external": "rightOption"
            ]
        )
        XCTAssertEqual(profile.requiredAttemptCount, 100)
        XCTAssertEqual(profile.maximumMissedAttemptCount, 1)
        XCTAssertEqual(profile.expectedSequenceTarget, 100)
        XCTAssertEqual(profile.minimumObservedSequenceCount, 99)
        XCTAssertEqual(profile.minimumLeftSequenceCount, 1)
        XCTAssertEqual(profile.minimumRightSequenceCount, 1)
        XCTAssertEqual(profile.minimumNoneSequenceCount, 1)
        XCTAssertEqual(profile.maximumMedianCallbackLatencyMilliseconds, 25)
    }
}
