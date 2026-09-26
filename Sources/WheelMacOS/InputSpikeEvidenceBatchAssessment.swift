/// Aggregates multiple independently validated evidence files while preserving
/// the manual physical-matrix gate.
public struct InputSpikeEvidenceBatchAssessment: Equatable, Sendable {
    public let outcome: InputSpikeEvidenceAssessment.Outcome
    public let passedCount: Int
    public let incompleteCount: Int
    public let failedCount: Int
    public let requiresManualReview: Bool

    public static func evaluate(
        _ assessments: [InputSpikeEvidenceAssessment]
    ) -> Self {
        let passedCount = assessments.filter { $0.outcome == .passed }.count
        let incompleteCount = assessments.filter { $0.outcome == .incomplete }.count
        let failedCount = assessments.filter { $0.outcome == .failed }.count

        let outcome: InputSpikeEvidenceAssessment.Outcome
        if assessments.isEmpty || failedCount > 0 {
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
            requiresManualReview: true
        )
    }
}
