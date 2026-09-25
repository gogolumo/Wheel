import Foundation

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
        if summary.sequenceTarget <= 0 || summary.completedSequenceCount < 0 {
            invalid.append("sequence counts must be non-negative and target must be positive")
        }
        if summary.leftCount < 0 || summary.rightCount < 0 || summary.noneCount < 0 {
            invalid.append("direction counts must be non-negative")
        }
        if summary.leftCount + summary.rightCount + summary.noneCount
            != summary.completedSequenceCount
        {
            invalid.append("direction counts do not equal completedSequenceCount")
        }
        if summary.observedTargetMet
            != (summary.completedSequenceCount >= summary.sequenceTarget)
        {
            invalid.append("observedTargetMet contradicts the sequence counts")
        }
        if summary.completionReason == .targetReached && !summary.observedTargetMet {
            invalid.append("targetReached contradicts the observed sequence count")
        }
        if summary.callbackSampleCount == 0
            && summary.medianCallbackLatencyMilliseconds != nil
        {
            invalid.append("median latency exists without callback samples")
        }
        let expectedLatencyResult = summary.medianCallbackLatencyMilliseconds.map {
            $0 < summary.latencyThresholdMilliseconds
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
