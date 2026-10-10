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

    func testRequiredPhysicalScenariosFailWhenAnAttestationIsMissing() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate(
            [entry("right-option-built-in", .passed)],
            requiredScenarios: ["finder", "chrome", "sleep-wake"],
            attestedScenariosByRunLabel: [
                "right-option-built-in": ["finder", "chrome"]
            ]
        )

        XCTAssertEqual(batch.outcome, .failed)
        XCTAssertEqual(
            batch.missingRequiredScenarios,
            ["right-option-built-in: sleep-wake"]
        )
    }

    func testRequiredPhysicalScenariosPassWithCompleteAttestations() {
        let scenarios = Set(["finder", "chrome", "vscode", "full-screen", "sleep-wake"])
        let batch = InputSpikeEvidenceBatchAssessment.evaluate(
            [entry("right-option-built-in", .passed)],
            requiredScenarios: scenarios,
            attestedScenariosByRunLabel: ["right-option-built-in": scenarios]
        )

        XCTAssertEqual(batch.outcome, .passed)
        XCTAssertTrue(batch.missingRequiredScenarios.isEmpty)
        XCTAssertTrue(batch.requiresManualReview)
    }

    func testRequiredPhysicalScenariosApplyToEveryRequiredRun() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate(
            [
                entry("caps-lock-built-in", .passed, trigger: "capsLock"),
                entry("caps-lock-external", .passed, trigger: "capsLock")
            ],
            requiredRuns: [
                "caps-lock-built-in": "capsLock",
                "caps-lock-external": "capsLock"
            ],
            requiredScenarios: ["finder", "sleep-wake"],
            attestedScenariosByRunLabel: [
                "caps-lock-built-in": ["finder", "sleep-wake"],
                "caps-lock-external": ["finder"]
            ]
        )

        XCTAssertEqual(batch.outcome, .failed)
        XCTAssertEqual(
            batch.missingRequiredScenarios,
            ["caps-lock-external: sleep-wake"]
        )
    }

    func testRequiredAttemptCountsCoverEveryRequiredRun() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate(
            [
                entry("caps-lock-built-in", .passed, trigger: "capsLock", completedSequenceCount: 99),
                entry("caps-lock-external", .passed, trigger: "capsLock", completedSequenceCount: 100)
            ],
            requiredRuns: [
                "caps-lock-built-in": "capsLock",
                "caps-lock-external": "capsLock"
            ],
            attestedAttemptCountByRunLabel: [
                "caps-lock-built-in": 100
            ],
            requiredAttemptCount: 100
        )

        XCTAssertEqual(batch.outcome, .failed)
        XCTAssertEqual(
            batch.attemptCountFindings,
            ["caps-lock-external (missing attempt attestation)"]
        )
    }

    func testAttemptCountCannotBeLowerThanObservedSequences() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate(
            [entry("right-option-built-in", .passed, completedSequenceCount: 100)],
            attestedAttemptCountByRunLabel: ["right-option-built-in": 99]
        )

        XCTAssertEqual(batch.outcome, .failed)
        XCTAssertEqual(
            batch.attemptCountFindings,
            ["right-option-built-in (100 observed exceeds 99 attested attempts)"]
        )
    }

    func testRequiredAttemptCountRejectsShorterEvidenceTarget() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate(
            [
                entry(
                    "right-option-built-in",
                    .passed,
                    sequenceTarget: 50,
                    completedSequenceCount: 50
                )
            ],
            attestedAttemptCountByRunLabel: ["right-option-built-in": 100],
            requiredAttemptCount: 100
        )

        XCTAssertEqual(batch.outcome, .failed)
        XCTAssertEqual(
            batch.attemptCountFindings,
            ["right-option-built-in (evidence target 50; required 100)"]
        )
    }

    func testMaximumMissedAttemptsFailsPerRun() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate(
            [
                entry(
                    "right-option-built-in",
                    .passed,
                    sequenceTarget: 100,
                    completedSequenceCount: 98
                )
            ],
            attestedAttemptCountByRunLabel: ["right-option-built-in": 100],
            requiredAttemptCount: 100,
            maximumMissedAttemptCount: 1
        )

        XCTAssertEqual(batch.outcome, .failed)
        XCTAssertEqual(
            batch.attemptCountFindings,
            ["right-option-built-in (2 missed; maximum 1)"]
        )
    }

    func testMaximumMissedAttemptsAllowsNinetyNineOfOneHundred() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate(
            [
                entry(
                    "right-option-built-in",
                    .passed,
                    sequenceTarget: 100,
                    completedSequenceCount: 99
                )
            ],
            attestedAttemptCountByRunLabel: ["right-option-built-in": 100],
            requiredAttemptCount: 100,
            maximumMissedAttemptCount: 1
        )

        XCTAssertEqual(batch.outcome, .passed)
        XCTAssertTrue(batch.attemptCountFindings.isEmpty)
    }

    func testInvalidMaximumMissedAttemptsFailsClosed() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate(
            [entry("right-option-built-in", .passed)],
            maximumMissedAttemptCount: -1
        )

        XCTAssertEqual(batch.outcome, .failed)
        XCTAssertEqual(
            batch.attemptCountFindings,
            ["invalid maximum missed-attempt count"]
        )
    }

    func testRequiredAttemptCountsPassWithCompleteAttestations() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate(
            [
                entry("caps-lock-built-in", .passed, trigger: "capsLock", completedSequenceCount: 99),
                entry("caps-lock-external", .passed, trigger: "capsLock", completedSequenceCount: 100)
            ],
            requiredRuns: [
                "caps-lock-built-in": "capsLock",
                "caps-lock-external": "capsLock"
            ],
            attestedAttemptCountByRunLabel: [
                "caps-lock-built-in": 100,
                "caps-lock-external": 100
            ],
            requiredAttemptCount: 100
        )

        XCTAssertEqual(batch.outcome, .passed)
        XCTAssertTrue(batch.attemptCountFindings.isEmpty)
    }

    func testEmptyBatchFailsClosed() {
        let batch = InputSpikeEvidenceBatchAssessment.evaluate([])

        XCTAssertEqual(batch.outcome, .failed)
        XCTAssertTrue(batch.requiresManualReview)
    }

    private func entry(
        _ runLabel: String,
        _ outcome: InputSpikeEvidenceAssessment.Outcome,
        trigger: String = "rightOption",
        sequenceTarget: Int = 100,
        completedSequenceCount: Int = 0
    ) -> InputSpikeEvidenceBatchEntry {
        InputSpikeEvidenceBatchEntry(
            runLabel: runLabel,
            trigger: trigger,
            sequenceTarget: sequenceTarget,
            completedSequenceCount: completedSequenceCount,
            assessment: InputSpikeEvidenceAssessment(
                outcome: outcome,
                findings: [],
                requiresManualReview: true
            )
        )
    }
}
