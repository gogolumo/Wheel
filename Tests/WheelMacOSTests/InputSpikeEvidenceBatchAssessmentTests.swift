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
