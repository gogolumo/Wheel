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
            trigger: "capsLock",
            sequenceTarget: 2,
            statistics: statistics
        )

        XCTAssertTrue(summary.observedTargetMet)
        XCTAssertEqual(summary.medianCallbackLatencyMilliseconds, 6)
        XCTAssertEqual(summary.latencyThresholdMet, true)
        XCTAssertTrue(summary.requiresManualReview)
    }

    func testMissingLatencyEvidenceRemainsUndecided() {
        let summary = InputSpikeRunSummary(
            runLabel: "no-events",
            trigger: "rightOption",
            sequenceTarget: 30,
            statistics: InputSpikeRunStatistics()
        )
        XCTAssertFalse(summary.observedTargetMet)
        XCTAssertNil(summary.latencyThresholdMet)
    }

    func testEncodedJSONContainsStableSchemaAndNoManualClaims() throws {
        let summary = InputSpikeRunSummary(
            runLabel: "external-mouse",
            trigger: "mouseSideButton",
            sequenceTarget: 30,
            statistics: InputSpikeRunStatistics()
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: summary.encodedJSON()) as? [String: Any]
        )
        XCTAssertEqual(object["schemaVersion"] as? Int, 1)
        XCTAssertEqual(object["runLabel"] as? String, "external-mouse")
        XCTAssertEqual(object["requiresManualReview"] as? Bool, true)
        XCTAssertNil(object["decision"])
        XCTAssertNil(object["stuckState"])
        XCTAssertNil(object["nativeSideEffects"])
    }
}
