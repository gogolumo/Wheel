public struct InputSpikeEvidenceProfile: Equatable, Sendable {
    public let requiredTriggers: Set<String>
    public let minimumRunCountByTrigger: [String: Int]
    public let requiredRuns: [String: String]
    public let requiredScenarios: Set<String>
    public let requiredRunReviews: Set<String>
    public let requiredEnvironmentAttestations: Set<String>
    public let minimumRecordingDurationSeconds: Int
    public let requiredDecision: InputSpikeEvidenceDecision
    public let requiredAttemptCount: Int
    public let maximumMissedAttemptCount: Int
    public let expectedSequenceTarget: Int
    public let minimumObservedSequenceCount: Int
    public let minimumLeftSequenceCount: Int
    public let minimumRightSequenceCount: Int
    public let minimumNoneSequenceCount: Int
    public let maximumMedianCallbackLatencyMilliseconds: Double

    public static let spike001Final = Self(
        requiredTriggers: ["capsLock", "rightOption"],
        minimumRunCountByTrigger: ["capsLock": 2, "rightOption": 2],
        requiredRuns: [
            "caps-lock-built-in": "capsLock",
            "caps-lock-external": "capsLock",
            "right-option-built-in": "rightOption",
            "right-option-external": "rightOption"
        ],
        requiredScenarios: [
            "finder",
            "chrome",
            "vscode",
            "full-screen",
            "sleep-wake",
            "timeout-recovery"
        ],
        requiredRunReviews: [
            "event-order",
            "intended-vs-observed",
            "stuck-state",
            "side-effects"
        ],
        requiredEnvironmentAttestations: ["clean-account", "signed-build"],
        minimumRecordingDurationSeconds: 120,
        requiredDecision: .go,
        requiredAttemptCount: 100,
        maximumMissedAttemptCount: 1,
        expectedSequenceTarget: 100,
        minimumObservedSequenceCount: 99,
        minimumLeftSequenceCount: 1,
        minimumRightSequenceCount: 1,
        minimumNoneSequenceCount: 1,
        maximumMedianCallbackLatencyMilliseconds: 25
    )
}
