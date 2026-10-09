import XCTest
@testable import WheelDomain
@testable import WheelMacOS

final class InputSpikeEvidenceAssessmentTests: XCTestCase {
    func testEvidenceCheckerDoesNotPrintPathsOrSystemErrors() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/WheelEvidenceCheck/main.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains(#"Evidence file: \(path)"#))
        XCTAssertFalse(source.contains(#"\(error)"#))
        XCTAssertTrue(source.contains(#"Evidence file #\(evidenceNumber)"#))
        XCTAssertTrue(source.contains("InputSpikeRunSummary.decodeValidatedJSON(data)"))
        XCTAssertFalse(
            source.contains("JSONDecoder().decode(InputSpikeRunSummary.self")
        )
        XCTAssertTrue(source.contains("--minimum-runs-per-trigger"))
        XCTAssertTrue(source.contains("--profile"))
        XCTAssertTrue(source.contains("--attest-scenario"))
        XCTAssertTrue(source.contains(".spike001Final"))
        XCTAssertTrue(source.contains("--require-run"))
        XCTAssertTrue(source.contains("--attempt-count"))
        XCTAssertTrue(source.contains("--required-attempt-count"))
        XCTAssertTrue(source.contains("--maximum-missed-attempts"))
        XCTAssertTrue(
            source.contains("minimumRunCountByTrigger: minimumRunCountByTrigger")
        )
        XCTAssertTrue(source.contains("requiredRuns: requiredRuns"))
        XCTAssertTrue(source.contains("attestedAttemptCountByRunLabel:"))
        XCTAssertTrue(source.contains("attestedScenarios: attestedScenarios"))
    }

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

    func testMinimumObservedRequirementAcceptsValidInterruptedEvidence() {
        let assessment = InputSpikeEvidenceAssessment.evaluate(
            makeSummary(
                sequenceTarget: 100,
                completedSequenceCount: 99,
                completionReason: .interrupted
            ),
            requirements: InputSpikeEvidenceRequirements(
                expectedTrigger: .rightOption,
                expectedSequenceTarget: 100,
                minimumObservedSequenceCount: 99,
                maximumMedianCallbackLatencyMilliseconds: 25
            )
        )

        XCTAssertEqual(assessment.outcome, .passed)
        XCTAssertTrue(
            assessment.findings.contains(
                "sequenceTarget matched the expected value of 100"
            )
        )
        XCTAssertTrue(
            assessment.findings.contains(
                "observed sequence count met the required minimum of 99"
            )
        )
        XCTAssertTrue(assessment.requiresManualReview)
    }

    func testExpectedSequenceTargetMismatchFailsClosed() {
        let assessment = InputSpikeEvidenceAssessment.evaluate(
            makeSummary(sequenceTarget: 99, completedSequenceCount: 99),
            requirements: InputSpikeEvidenceRequirements(
                expectedSequenceTarget: 100,
                minimumObservedSequenceCount: 99
            )
        )

        XCTAssertEqual(assessment.outcome, .failed)
        XCTAssertTrue(
            assessment.findings.contains(
                "sequenceTarget 99 does not match expected 100"
            )
        )
    }

    func testMinimumObservedRequirementKeepsShortRunIncomplete() {
        let assessment = InputSpikeEvidenceAssessment.evaluate(
            makeSummary(
                sequenceTarget: 100,
                completedSequenceCount: 98,
                completionReason: .interrupted
            ),
            requirements: InputSpikeEvidenceRequirements(
                minimumObservedSequenceCount: 99
            )
        )

        XCTAssertEqual(assessment.outcome, .incomplete)
        XCTAssertTrue(
            assessment.findings.contains(
                "observed sequence count did not meet the required minimum of 99"
            )
        )
    }

    func testExpectedTriggerMismatchFailsClosed() {
        let assessment = InputSpikeEvidenceAssessment.evaluate(
            makeSummary(),
            requirements: InputSpikeEvidenceRequirements(expectedTrigger: .capsLock)
        )

        XCTAssertEqual(assessment.outcome, .failed)
        XCTAssertTrue(
            assessment.findings.contains(
                "trigger rightOption does not match expected capsLock"
            )
        )
    }

    func testMinimumDirectionRequirementsAcceptCompleteCoverage() {
        let assessment = InputSpikeEvidenceAssessment.evaluate(
            makeSummary(
                sequenceTarget: 3,
                completedSequenceCount: 3,
                directions: [.left, .right, .none]
            ),
            requirements: InputSpikeEvidenceRequirements(
                minimumLeftSequenceCount: 1,
                minimumRightSequenceCount: 1,
                minimumNoneSequenceCount: 1
            )
        )

        XCTAssertEqual(assessment.outcome, .passed)
        XCTAssertTrue(
            assessment.findings.contains(
                "LEFT sequence count met the required minimum of 1"
            )
        )
        XCTAssertTrue(
            assessment.findings.contains(
                "RIGHT sequence count met the required minimum of 1"
            )
        )
        XCTAssertTrue(
            assessment.findings.contains(
                "NONE sequence count met the required minimum of 1"
            )
        )
    }

    func testMinimumDirectionRequirementsRejectMissingCoverage() {
        let assessment = InputSpikeEvidenceAssessment.evaluate(
            makeSummary(sequenceTarget: 3, completedSequenceCount: 3),
            requirements: InputSpikeEvidenceRequirements(
                minimumLeftSequenceCount: 1,
                minimumRightSequenceCount: 1,
                minimumNoneSequenceCount: 1
            )
        )

        XCTAssertEqual(assessment.outcome, .failed)
        XCTAssertTrue(
            assessment.findings.contains(
                "RIGHT sequence count did not meet the required minimum of 1"
            )
        )
        XCTAssertTrue(
            assessment.findings.contains(
                "NONE sequence count did not meet the required minimum of 1"
            )
        )
    }

    func testImpossibleDirectionRequirementsFailClosed() {
        let assessment = InputSpikeEvidenceAssessment.evaluate(
            makeSummary(sequenceTarget: 2, completedSequenceCount: 2),
            requirements: InputSpikeEvidenceRequirements(
                minimumLeftSequenceCount: 1,
                minimumRightSequenceCount: 1,
                minimumNoneSequenceCount: 1
            )
        )

        XCTAssertEqual(assessment.outcome, .failed)
        XCTAssertTrue(
            assessment.findings.contains(
                "minimum direction requirements exceed sequenceTarget"
            )
        )
    }

    func testOverflowingDirectionRequirementsFailClosed() {
        let assessment = InputSpikeEvidenceAssessment.evaluate(
            makeSummary(),
            requirements: InputSpikeEvidenceRequirements(
                minimumLeftSequenceCount: Int.max,
                minimumRightSequenceCount: Int.max
            )
        )

        XCTAssertEqual(assessment.outcome, .failed)
        XCTAssertTrue(
            assessment.findings.contains(
                "minimum direction requirements exceed sequenceTarget"
            )
        )
    }

    func testStricterMaximumMedianLatencyFailsClosed() {
        let assessment = InputSpikeEvidenceAssessment.evaluate(
            makeSummary(latencyMilliseconds: 12),
            requirements: InputSpikeEvidenceRequirements(
                maximumMedianCallbackLatencyMilliseconds: 10
            )
        )

        XCTAssertEqual(assessment.outcome, .failed)
        XCTAssertTrue(
            assessment.findings.contains(
                "median callback latency did not meet the required maximum of 10.0 ms"
            )
        )
    }

    func testInvalidRequirementsFailClosed() {
        let assessment = InputSpikeEvidenceAssessment.evaluate(
            makeSummary(sequenceTarget: 10, completionReason: .interrupted),
            requirements: InputSpikeEvidenceRequirements(
                expectedSequenceTarget: 0,
                minimumObservedSequenceCount: 11,
                minimumLeftSequenceCount: 0,
                maximumMedianCallbackLatencyMilliseconds: .infinity
            )
        )

        XCTAssertEqual(assessment.outcome, .failed)
        XCTAssertTrue(
            assessment.findings.contains("expected sequence target must be positive")
        )
        XCTAssertTrue(
            assessment.findings.contains(
                "minimum observed sequence requirement exceeds sequenceTarget"
            )
        )
        XCTAssertTrue(
            assessment.findings.contains(
                "minimum LEFT sequence requirement must be positive"
            )
        )
        XCTAssertTrue(
            assessment.findings.contains(
                "maximum median callback latency must be finite and positive"
            )
        )
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

    func testRejectsCompletedSequenceCountAboveTarget() throws {
        let assessment = InputSpikeEvidenceAssessment.evaluate(
            try tamperedSummary {
                $0["completedSequenceCount"] = 2
                $0["leftCount"] = 2
            }
        )

        XCTAssertEqual(assessment.outcome, .failed)
        XCTAssertTrue(
            assessment.findings.contains(
                "completedSequenceCount exceeds sequenceTarget"
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
        completedSequenceCount: Int = 1,
        completionReason: InputSpikeRunSummary.CompletionReason = .targetReached,
        latencyMilliseconds: Double = 8,
        directions: [Direction]? = nil
    ) -> InputSpikeRunSummary {
        var statistics = InputSpikeRunStatistics()
        let recordedDirections = directions
            ?? Array(repeating: Direction.left, count: completedSequenceCount)
        precondition(recordedDirections.count == completedSequenceCount)
        for direction in recordedDirections {
            statistics.recordCompletedSequence(direction: direction)
        }
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
