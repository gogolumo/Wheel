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
        let data = try makeSummary().encodedJSON()
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object["observedTargetMet"] = false
        let tampered = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(InputSpikeRunSummary.self, from: tampered)

        let assessment = InputSpikeEvidenceAssessment.evaluate(decoded)

        XCTAssertEqual(assessment.outcome, .failed)
        XCTAssertTrue(
            assessment.findings.contains(
                "observedTargetMet contradicts the sequence counts"
            )
        )
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
