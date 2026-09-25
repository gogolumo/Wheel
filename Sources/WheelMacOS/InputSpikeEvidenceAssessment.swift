import Foundation
import WheelDomain

/// Validates one privacy-safe SPIKE-002 export without turning automated
/// telemetry into a physical-device GO decision.
public struct InputSpikeEvidenceAssessment: Equatable, Sendable {
    public enum Outcome: String, Equatable, Sendable {
        case passed
        case incomplete
        case failed
    }

    public let outcome: Outcome
    public let findings: [String]
    public let requiresManualReview: Bool

    public static func evaluate(_ summary: InputSpikeRunSummary) -> Self {
        var invalid: [String] = []

        if summary.schemaVersion != 3 {
            invalid.append("unsupported schemaVersion \(summary.schemaVersion); expected 3")
        }
        if InputEvidenceRunLabel.validationError(for: summary.runLabel) != nil {
            invalid.append("runLabel violates the privacy-safe label contract")
        }

        let trigger = TriggerType(rawValue: summary.trigger)
        if trigger == nil {
            invalid.append("trigger is not a supported TriggerType")
        }
        if trigger == .mouseSideButton {
            if summary.mouseButtonNumber.map({ $0 >= 3 }) != true {
                invalid.append("mouse-side-button evidence requires a button number of at least 3")
            }
        } else if summary.mouseButtonNumber != nil {
            invalid.append("mouseButtonNumber is only valid for mouse-side-button evidence")
        }

        if !summary.minimumHorizontalDistance.isFinite
            || summary.minimumHorizontalDistance <= 0
        {
            invalid.append("minimumHorizontalDistance must be finite and positive")
        }
        if !summary.minimumDominanceRatio.isFinite
            || summary.minimumDominanceRatio < 1
        {
            invalid.append("minimumDominanceRatio must be finite and at least 1")
        }
        if summary.sequenceTarget <= 0 || summary.completedSequenceCount < 0 {
            invalid.append("sequence counts must be non-negative and target must be positive")
        }
        if summary.leftCount < 0 || summary.rightCount < 0 || summary.noneCount < 0 {
            invalid.append("direction counts must be non-negative")
        }

        let (leftAndRight, firstCountOverflow) = summary.leftCount.addingReportingOverflow(
            summary.rightCount
        )
        let (directionCount, secondCountOverflow) = leftAndRight.addingReportingOverflow(
            summary.noneCount
        )
        if firstCountOverflow || secondCountOverflow {
            invalid.append("direction counts overflow")
        } else if directionCount != summary.completedSequenceCount {
            invalid.append("direction counts do not equal completedSequenceCount")
        }
        if summary.pointerMovementCount < 0
            || summary.callbackSampleCount < 0
            || summary.eventTapRecoveryCount < 0
        {
            invalid.append("aggregate event counts must be non-negative")
        }
        if summary.observedTargetMet
            != (summary.completedSequenceCount >= summary.sequenceTarget)
        {
            invalid.append("observedTargetMet contradicts the sequence counts")
        }
        if (summary.completionReason == .targetReached) != summary.observedTargetMet {
            invalid.append("completionReason contradicts whether the target was met")
        }

        if (summary.callbackSampleCount == 0)
            != (summary.medianCallbackLatencyMilliseconds == nil)
        {
            invalid.append("callback sample count and median latency disagree")
        }
        if let median = summary.medianCallbackLatencyMilliseconds,
           !median.isFinite || median < 0
        {
            invalid.append("median callback latency must be finite and non-negative")
        }
        if !summary.latencyThresholdMilliseconds.isFinite
            || summary.latencyThresholdMilliseconds <= 0
        {
            invalid.append("latency threshold must be finite and positive")
        }

        let expectedLatencyResult: Bool?
        if let median = summary.medianCallbackLatencyMilliseconds,
           median.isFinite,
           median >= 0,
           summary.latencyThresholdMilliseconds.isFinite,
           summary.latencyThresholdMilliseconds > 0
        {
            expectedLatencyResult = median < summary.latencyThresholdMilliseconds
        } else {
            expectedLatencyResult = nil
        }
        if summary.latencyThresholdMet != expectedLatencyResult {
            invalid.append("latencyThresholdMet contradicts the measured median")
        }
        if !summary.requiresManualReview {
            invalid.append("SPIKE-002 evidence must require manual review")
        }

        if !invalid.isEmpty {
            return Self(outcome: .failed, findings: invalid, requiresManualReview: true)
        }

        var incomplete: [String] = []
        if summary.completionReason != .targetReached || !summary.observedTargetMet {
            incomplete.append("observed sequence target was not completed")
        }
        if summary.latencyThresholdMet == nil {
            incomplete.append("callback latency has no samples")
        }
        if !incomplete.isEmpty {
            return Self(outcome: .incomplete, findings: incomplete, requiresManualReview: true)
        }

        if summary.latencyThresholdMet == false {
            return Self(
                outcome: .failed,
                findings: ["median callback latency did not meet the configured threshold"],
                requiresManualReview: true
            )
        }

        return Self(
            outcome: .passed,
            findings: [
                "export structure is internally consistent",
                "observed sequence target was completed",
                "median callback latency met the configured threshold"
            ],
            requiresManualReview: true
        )
    }
}
