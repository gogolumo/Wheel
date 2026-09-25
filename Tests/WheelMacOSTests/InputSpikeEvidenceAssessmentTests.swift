import XCTest
@testable import WheelDomain
@testable import WheelMacOS

final class InputSpikeEvidenceAssessmentTests: XCTestCase {
    func testPassesCompleteConsistentExportButKeepsManualGate() {
        let assessment = InputSpikeEvidenceAssessment.evaluate(makeSummary())

        XCTAssertEqual(assessment.outcome, .passed)
        XCTAssertTrue(assessment.requiresManualReview)
    }

    func testMarksInterruptedExportIncomplete() {
        let assessment = InputSpikeEvidenceAssessment.evaluate(
            makeSummary(sequenceTarget: 2, completionReason: .interrupted)
        )

        XCTAssertEqual(assessment.outcome, .incomplete)
        XCTAssertTrue(assessment.findings.contains("observed sequence target was not completed"))
    }

    func testFailsLatencyThreshold() {
        let assessment = InputSpikeEvidenceAssessment.evaluate(
            makeSummary(latencyMilliseconds: 30)
        )

        XCTAssertEqual(assessment.outcome, .failed)
    }

    func testRejectsTamperedDerivedFieldsWhenDecoded() throws {
        let assessment = InputSpikeEvidenceAssessment.evaluate(
            try tamperedSummary { $0["observedTargetMet"] = false }
        )

        XCTAssertEqual(assessment.outcome, .failed)
        XCTAssertTrue(
            assessment.findings.contains(
                "observedTargetMet contradicts the sequence counts"
            )
        )
    }

    func testRejectsUnknownTriggerAndTriggerButtonMismatch() throws {
        let unknownTrigger = InputSpikeEvidenceAssessment.evaluate(
            try tamperedSummary { $0["trigger"] = "keyboardShortcut" }
        )
        let unexpectedButton = InputSpikeEvidenceAssessment.evaluate(
            try tamperedSummary { $0["mouseButtonNumber"] = 4 }
        )
        let missingButton = InputSpikeEvidenceAssessment.evaluate(
            try tamperedSummary { $0["trigger"] = "mouseSideButton" }
        )

        XCTAssertEqual(unknownTrigger.outcome, .failed)
        XCTAssertTrue(
            unknownTrigger.findings.contains("trigger is not a supported TriggerType")
        )
        XCTAssertEqual(unexpectedButton.outcome, .failed)
        XCTAssertTrue(
            unexpectedButton.findings.contains(
                "mouseButtonNumber is only valid for mouse-side-button evidence"
            )
        )
        XCTAssertEqual(missingButton.outcome, .failed)
        XCTAssertTrue(
            missingButton.findings.contains(
                "mouse-side-button evidence requires a button number of at least 3"
            )
        )
    }

    func testRejectsInvalidClassifierAndAggregateValues() throws {
        let assessment = InputSpikeEvidenceAssessment.evaluate(
            try tamperedSummary {
                $0["minimumHorizontalDistance"] = 0
                $0["minimumDominanceRatio"] = 0.5
                $0["pointerMovementCount"] = -1
                $0["eventTapRecoveryCount"] = -1
                $0["latencyThresholdMilliseconds"] = 0
            }
        )

        XCTAssertEqual(assessment.outcome, .failed)
        XCTAssertTrue(
            assessment.findings.contains(
                "minimumHorizontalDistance must be finite and positive"
            )
        )
        XCTAssertTrue(
            assessment.findings.contains(
                "minimumDominanceRatio must be finite and at least 1"
            )
        )
        XCTAssertTrue(
            assessment.findings.contains("aggregate event counts must be non-negative")
        )
        XCTAssertTrue(
            assessment.findings.contains("latency threshold must be finite and positive")
        )
    }

    func testRejectsMissingMedianForRecordedCallbackSamples() throws {
        let assessment = InputSpikeEvidenceAssessment.evaluate(
            try tamperedSummary {
                $0["medianCallbackLatencyMilliseconds"] = NSNull()
                $0["latencyThresholdMet"] = NSNull()
            }
        )

        XCTAssertEqual(assessment.outcome, .failed)
        XCTAssertTrue(
            assessment.findings.contains(
                "callback sample count and median latency disagree"
            )
        )
    }

    func testRejectsInterruptedRunThatClaimsCompletedTarget() throws {
        let assessment = InputSpikeEvidenceAssessment.evaluate(
            try tamperedSummary { $0["completionReason"] = "interrupted" }
        )

        XCTAssertEqual(assessment.outcome, .failed)
        XCTAssertTrue(
            assessment.findings.contains(
                "completionReason contradicts whether the target was met"
            )
        )
    }

    func testRejectsDirectionCountOverflowWithoutCrashing() throws {
        let assessment = InputSpikeEvidenceAssessment.evaluate(
            try tamperedSummary {
                $0["leftCount"] = Int.max
                $0["rightCount"] = Int.max
            }
        )

        XCTAssertEqual(assessment.outcome, .failed)
        XCTAssertTrue(assessment.findings.contains("direction counts overflow"))
    }

    private func tamperedSummary(
        _ update: (inout [String: Any]) -> Void
    ) throws -> InputSpikeRunSummary {
        let data = try makeSummary().encodedJSON()
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        update(&object)
        let tampered = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(InputSpikeRunSummary.self, from: tampered)
    }

    private func makeSummary(
        sequenceTarget: Int = 1,
        completionReason: InputSpikeRunSummary.CompletionReason = .targetReached,
        latencyMilliseconds: Double = 8
    ) -> InputSpikeRunSummary {
        var statistics = InputSpikeRunStatistics()
        statistics.recordCompletedSequence(direction: .left)
        statistics.recordCallbackLatency(milliseconds: latencyMilliseconds)
        return InputSpikeRunSummary(
            runLabel: "right-option-finder",
            trigger: .rightOption,
            minimumHorizontalDistance: 80,
            minimumDominanceRatio: 1.5,
            sequenceTarget: sequenceTarget,
            statistics: statistics,
            completionReason: completionReason
        )
    }
}
