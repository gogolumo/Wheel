public struct InputSpikeEvidenceBatchEntry: Equatable, Sendable {
    public let runLabel: String
    public let trigger: String
    public let completedSequenceCount: Int
    public let assessment: InputSpikeEvidenceAssessment

    public init(
        runLabel: String,
        trigger: String,
        completedSequenceCount: Int = 0,
        assessment: InputSpikeEvidenceAssessment
    ) {
        self.runLabel = runLabel
        self.trigger = trigger
        self.completedSequenceCount = completedSequenceCount
        self.assessment = assessment
    }
}

/// Aggregates multiple independently validated evidence files while preserving
/// the manual physical-matrix gate.
public struct InputSpikeEvidenceBatchAssessment: Equatable, Sendable {
    public let outcome: InputSpikeEvidenceAssessment.Outcome
    public let passedCount: Int
    public let incompleteCount: Int
    public let failedCount: Int
    public let duplicateRunLabels: [String]
    public let missingRequiredTriggers: [String]
    public let insufficientTriggerRunCounts: [String]
    public let requiredRunFindings: [String]
    public let attemptCountFindings: [String]
    public let requiresManualReview: Bool

    public static func evaluate(
        _ entries: [InputSpikeEvidenceBatchEntry],
        requiredTriggers: Set<String> = [],
        minimumRunCountByTrigger: [String: Int] = [:],
        requiredRuns: [String: String] = [:],
        attestedAttemptCountByRunLabel: [String: Int] = [:],
        requiredAttemptCount: Int? = nil
    ) -> Self {
        let assessments = entries.map(\.assessment)
        let passedCount = assessments.filter { $0.outcome == .passed }.count
        let incompleteCount = assessments.filter { $0.outcome == .incomplete }.count
        let failedCount = assessments.filter { $0.outcome == .failed }.count
        let duplicateRunLabels = Dictionary(grouping: entries, by: \.runLabel)
            .filter { $0.value.count > 1 }
            .map(\.key)
            .sorted()
        let observedTriggers = Set(entries.map(\.trigger))
        let missingRequiredTriggers = requiredTriggers
            .subtracting(observedTriggers)
            .sorted()
        let observedRunCountByTrigger = Dictionary(grouping: entries, by: \.trigger)
            .mapValues(\.count)
        let insufficientTriggerRunCounts = minimumRunCountByTrigger
            .compactMap { trigger, requiredCount -> String? in
                guard requiredCount > 0 else {
                    return "\(trigger) (invalid minimum \(requiredCount))"
                }
                let observedCount = observedRunCountByTrigger[trigger, default: 0]
                guard observedCount < requiredCount else { return nil }
                return "\(trigger) (\(observedCount)/\(requiredCount))"
            }
            .sorted()
        let entriesByRunLabel = Dictionary(grouping: entries, by: \.runLabel)
        let supportedTriggers = Set([
            "capsLock",
            "rightOption",
            "mouseSideButton"
        ])
        let requiredRunFindings = requiredRuns
            .compactMap { runLabel, expectedTrigger -> String? in
                guard InputEvidenceRunLabel.validationError(for: runLabel) == nil else {
                    return "required run contract contains an invalid privacy-safe label"
                }
                guard supportedTriggers.contains(expectedTrigger) else {
                    return "\(runLabel) (unsupported expected trigger)"
                }
                guard let entry = entriesByRunLabel[runLabel]?.first else {
                    return "\(runLabel) (missing; expected \(expectedTrigger))"
                }
                guard entry.trigger != expectedTrigger else { return nil }
                return "\(runLabel) (observed \(entry.trigger); "
                    + "expected \(expectedTrigger))"
            }
            .sorted()
        let requiredAttemptLabels = requiredRuns.isEmpty
            ? Set(entries.map(\.runLabel))
            : Set(requiredRuns.keys)
        var attemptCountFindings = attestedAttemptCountByRunLabel
            .compactMap { runLabel, attemptCount -> String? in
                guard InputEvidenceRunLabel.validationError(for: runLabel) == nil else {
                    return "attempt contract contains an invalid privacy-safe label"
                }
                guard attemptCount > 0 else {
                    return "\(runLabel) (invalid attempt count)"
                }
                guard let entry = entriesByRunLabel[runLabel]?.first else {
                    return "\(runLabel) (attempt count has no evidence run)"
                }
                guard entry.completedSequenceCount <= attemptCount else {
                    return "\(runLabel) (\(entry.completedSequenceCount) observed exceeds "
                        + "\(attemptCount) attested attempts)"
                }
                return nil
            }
        if let requiredAttemptCount {
            if requiredAttemptCount <= 0 {
                attemptCountFindings.append("invalid required attempt count")
            } else {
                attemptCountFindings.append(contentsOf: requiredAttemptLabels.compactMap { runLabel in
                    guard let attested = attestedAttemptCountByRunLabel[runLabel] else {
                        return "\(runLabel) (missing attempt attestation)"
                    }
                    guard attested == requiredAttemptCount else {
                        return "\(runLabel) (attested \(attested); required \(requiredAttemptCount))"
                    }
                    return nil
                })
            }
        }
        attemptCountFindings.sort()

        let outcome: InputSpikeEvidenceAssessment.Outcome
        if entries.isEmpty
            || failedCount > 0
            || !duplicateRunLabels.isEmpty
            || !missingRequiredTriggers.isEmpty
            || !insufficientTriggerRunCounts.isEmpty
            || !requiredRunFindings.isEmpty
            || !attemptCountFindings.isEmpty {
            outcome = .failed
        } else if incompleteCount > 0 {
            outcome = .incomplete
        } else {
            outcome = .passed
        }

        return Self(
            outcome: outcome,
            passedCount: passedCount,
            incompleteCount: incompleteCount,
            failedCount: failedCount,
            duplicateRunLabels: duplicateRunLabels,
            missingRequiredTriggers: missingRequiredTriggers,
            insufficientTriggerRunCounts: insufficientTriggerRunCounts,
            requiredRunFindings: requiredRunFindings,
            attemptCountFindings: attemptCountFindings,
            requiresManualReview: true
        )
    }
}
