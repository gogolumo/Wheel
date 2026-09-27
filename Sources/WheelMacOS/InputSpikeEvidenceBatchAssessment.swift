public struct InputSpikeEvidenceBatchEntry: Equatable, Sendable {
    public let runLabel: String
    public let assessment: InputSpikeEvidenceAssessment

    public init(runLabel: String, assessment: InputSpikeEvidenceAssessment) {
        self.runLabel = runLabel
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
    public let requiresManualReview: Bool

    public static func evaluate(
        _ entries: [InputSpikeEvidenceBatchEntry]
    ) -> Self {
        let assessments = entries.map(\.assessment)
        let passedCount = assessments.filter { $0.outcome == .passed }.count
        let incompleteCount = assessments.filter { $0.outcome == .incomplete }.count
        let failedCount = assessments.filter { $0.outcome == .failed }.count
        let duplicateRunLabels = Dictionary(grouping: entries, by: \.runLabel)
            .filter { $0.value.count > 1 }
            .map(\.key)
            .sorted()

        let outcome: InputSpikeEvidenceAssessment.Outcome
        if entries.isEmpty || failedCount > 0 || !duplicateRunLabels.isEmpty {
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
            requiresManualReview: true
        )
    }
}
