import Foundation
import XCTest
@testable import WheelDomain
@testable import WheelMacOS

final class InputSpikeRunSummaryTests: XCTestCase {
    func testBuildsThresholdChecksWithoutClaimingAutomaticDecision() {
        var statistics = InputSpikeRunStatistics()
        statistics.recordCompletedSequence(direction: .left)
        statistics.recordCompletedSequence(direction: .right)
        statistics.recordCallbackLatency(milliseconds: 4)
        statistics.recordCallbackLatency(milliseconds: 8)

        let summary = InputSpikeRunSummary(
            runLabel: "built-in-trackpad",
            trigger: .capsLock,
            minimumHorizontalDistance: 120,
            minimumDominanceRatio: 2,
            sequenceTarget: 2,
            statistics: statistics,
            completionReason: .targetReached
        )

        XCTAssertTrue(summary.observedTargetMet)
        XCTAssertEqual(summary.minimumHorizontalDistance, 120)
        XCTAssertEqual(summary.minimumDominanceRatio, 2)
        XCTAssertEqual(summary.medianCallbackLatencyMilliseconds, 6)
        XCTAssertEqual(summary.latencyThresholdMilliseconds, 25)
        XCTAssertEqual(summary.latencyThresholdMet, true)
        XCTAssertEqual(summary.completionReason, .targetReached)
        XCTAssertTrue(summary.requiresManualReview)
    }

    func testMissingLatencyEvidenceRemainsUndecided() {
        let summary = InputSpikeRunSummary(
            runLabel: "no-events",
            trigger: .rightOption,
            minimumHorizontalDistance: 80,
            minimumDominanceRatio: 1.5,
            sequenceTarget: 30,
            statistics: InputSpikeRunStatistics(),
            completionReason: .interrupted
        )
        XCTAssertFalse(summary.observedTargetMet)
        XCTAssertNil(summary.latencyThresholdMet)
        XCTAssertNil(summary.mouseButtonNumber)
        XCTAssertEqual(summary.completionReason, .interrupted)
    }

    func testEncodedJSONContainsStableSchemaAndNoManualClaims() throws {
        let summary = InputSpikeRunSummary(
            runLabel: "external-mouse",
            trigger: .mouseSideButton,
            minimumHorizontalDistance: 90,
            minimumDominanceRatio: 1.75,
            mouseButtonNumber: 4,
            sequenceTarget: 30,
            statistics: InputSpikeRunStatistics(),
            completionReason: .interrupted,
            latencyThresholdMilliseconds: 20
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: summary.encodedJSON()) as? [String: Any]
        )
        XCTAssertEqual(object["schemaVersion"] as? Int, 3)
        XCTAssertEqual(object["runLabel"] as? String, "external-mouse")
        XCTAssertEqual(object["minimumHorizontalDistance"] as? Double, 90)
        XCTAssertEqual(object["minimumDominanceRatio"] as? Double, 1.75)
        XCTAssertEqual(object["mouseButtonNumber"] as? Int, 4)
        XCTAssertEqual(object["latencyThresholdMilliseconds"] as? Double, 20)
        XCTAssertEqual(object["requiresManualReview"] as? Bool, true)
        XCTAssertEqual(object["completionReason"] as? String, "interrupted")
        XCTAssertNil(object["decision"])
        XCTAssertNil(object["stuckState"])
        XCTAssertNil(object["nativeSideEffects"])
    }
}
