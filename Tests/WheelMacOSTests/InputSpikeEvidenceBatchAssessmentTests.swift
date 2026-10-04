import XCTest
@testable import WheelMacOS

final class InputSpikeEvidenceBatchAssessmentTests: XCTestCase {
    func testPassesOnlyWhenEveryFilePasses() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate([
            entry("right-option-finder", .passed),
            entry("caps-lock-finder", .passed)
        ])

        XCTAssertEqual(batch.outcome, .passed)
        XCTAssertEqual(batch.passedCount, 2)
        XCTAssertTrue(batch.requiresManualReview)
    }

    func testIncompleteTakesPrecedenceOverPass() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate([
            entry("right-option-finder", .passed),
            entry("caps-lock-finder", .incomplete)
        ])

        XCTAssertEqual(batch.outcome, .incomplete)
        XCTAssertEqual(batch.incompleteCount, 1)
    }

    func testFailureTakesPrecedenceOverIncomplete() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate([
            entry("right-option-finder", .incomplete),
            entry("caps-lock-finder", .failed)
        ])

        XCTAssertEqual(batch.outcome, .failed)
        XCTAssertEqual(batch.failedCount, 1)
    }

    func testDuplicateRunLabelsFailClosed() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate([
            entry("right-option-finder", .passed),
            entry("right-option-finder", .passed)
        ])

        XCTAssertEqual(batch.outcome, .failed)
        XCTAssertEqual(batch.duplicateRunLabels, ["right-option-finder"])
    }

    func testRequiredTriggerCoverageFailsClosed() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate(
            [
                entry("right-option-finder", .passed, trigger: "rightOption"),
                entry("caps-lock-finder", .passed, trigger: "capsLock")
            ],
            requiredTriggers: ["rightOption", "capsLock", "mouseSideButton"]
        )

        XCTAssertEqual(batch.outcome, .failed)
        XCTAssertEqual(batch.missingRequiredTriggers, ["mouseSideButton"])
    }

    func testRequiredTriggerCoveragePassesWhenEveryCandidateIsPresent() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate(
            [
                entry("right-option-finder", .passed, trigger: "rightOption"),
                entry("caps-lock-finder", .passed, trigger: "capsLock"),
                entry("mouse-button-finder", .passed, trigger: "mouseSideButton")
            ],
            requiredTriggers: ["rightOption", "capsLock", "mouseSideButton"]
        )

        XCTAssertEqual(batch.outcome, .passed)
        XCTAssertTrue(batch.missingRequiredTriggers.isEmpty)
    }

    func testMinimumRunsPerTriggerFailsClosed() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate(
            [
                entry("right-option-built-in", .passed, trigger: "rightOption"),
                entry("caps-lock-built-in", .passed, trigger: "capsLock"),
                entry("caps-lock-external", .passed, trigger: "capsLock")
            ],
            minimumRunCountByTrigger: ["rightOption": 2, "capsLock": 2]
        )

        XCTAssertEqual(batch.outcome, .failed)
        XCTAssertEqual(batch.insufficientTriggerRunCounts, ["rightOption (1/2)"])
    }

    func testMinimumRunsPerTriggerPassesWithIndependentLabels() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate(
            [
                entry("right-option-built-in", .passed, trigger: "rightOption"),
                entry("right-option-external", .passed, trigger: "rightOption"),
                entry("caps-lock-built-in", .passed, trigger: "capsLock"),
                entry("caps-lock-external", .passed, trigger: "capsLock")
            ],
            minimumRunCountByTrigger: ["rightOption": 2, "capsLock": 2]
        )

        XCTAssertEqual(batch.outcome, .passed)
        XCTAssertTrue(batch.insufficientTriggerRunCounts.isEmpty)
    }

    func testInvalidMinimumRunsPerTriggerFailsClosed() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate(
            [entry("caps-lock-built-in", .passed, trigger: "capsLock")],
            minimumRunCountByTrigger: ["capsLock": 0]
        )

        XCTAssertEqual(batch.outcome, .failed)
        XCTAssertEqual(
            batch.insufficientTriggerRunCounts,
            ["capsLock (invalid minimum 0)"]
        )
    }

    func testRequiredRunsFailWhenMissingOrBoundToWrongTrigger() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate(
            [
                entry("right-option-built-in", .passed, trigger: "capsLock")
            ],
            requiredRuns: [
                "right-option-built-in": "rightOption",
                "caps-lock-external": "capsLock"
            ]
        )

        XCTAssertEqual(batch.outcome, .failed)
        XCTAssertEqual(
            batch.requiredRunFindings,
            [
                "caps-lock-external (missing; expected capsLock)",
                "right-option-built-in (observed capsLock; expected rightOption)"
            ]
        )
    }

    func testRequiredRunsPassWhenEveryLabelMatchesItsTrigger() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate(
            [
                entry("right-option-built-in", .passed, trigger: "rightOption"),
                entry("caps-lock-external", .passed, trigger: "capsLock")
            ],
            requiredRuns: [
                "right-option-built-in": "rightOption",
                "caps-lock-external": "capsLock"
            ]
        )

        XCTAssertEqual(batch.outcome, .passed)
        XCTAssertTrue(batch.requiredRunFindings.isEmpty)
    }

    func testInvalidRequiredRunContractFailsClosed() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate(
            [entry("caps-lock-built-in", .passed, trigger: "capsLock")],
            requiredRuns: [
                "private/path": "capsLock",
                "caps-lock-built-in": "keyboardShortcut"
            ]
        )

        XCTAssertEqual(batch.outcome, .failed)
        XCTAssertEqual(
            batch.requiredRunFindings,
            [
                "caps-lock-built-in (unsupported expected trigger)",
                "required run contract contains an invalid privacy-safe label"
            ]
        )
    }

    func testEmptyBatchFailsClosed() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate([])

        XCTAssertEqual(batch.outcome, .failed)
        XCTAssertTrue(batch.requiresManualReview)
    }

    private func entry(
        _ runLabel: String,
        _ outcome: InputSpikeEvidenceAssessment.Outcome,
        trigger: String = "rightOption"
    ) -> InputSpikeEvidenceBatchEntry {
        InputSpikeEvidenceBatchEntry(
            runLabel: runLabel,
            trigger: trigger,
            assessment: InputSpikeEvidenceAssessment(
                outcome: outcome,
                findings: [],
                requiresManualReview: true
            )
        )
    }
}
