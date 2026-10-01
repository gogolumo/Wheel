import WheelDomain

/// Optional acceptance requirements applied while checking an evidence export.
///
/// These requirements validate aggregate evidence only. They cannot establish
/// the physical-attempt count, device/application coverage, stuck-state result,
/// or native side effects, so the manual gate remains mandatory.
public struct InputSpikeEvidenceRequirements: Equatable, Sendable {
    public let expectedTrigger: TriggerType?
    public let expectedSequenceTarget: Int?
    public let minimumObservedSequenceCount: Int?
    public let minimumLeftSequenceCount: Int?
    public let minimumRightSequenceCount: Int?
    public let minimumNoneSequenceCount: Int?
    public let maximumMedianCallbackLatencyMilliseconds: Double?

    public init(
        expectedTrigger: TriggerType? = nil,
        expectedSequenceTarget: Int? = nil,
        minimumObservedSequenceCount: Int? = nil,
        minimumLeftSequenceCount: Int? = nil,
        minimumRightSequenceCount: Int? = nil,
        minimumNoneSequenceCount: Int? = nil,
        maximumMedianCallbackLatencyMilliseconds: Double? = nil
    ) {
        self.expectedTrigger = expectedTrigger
        self.expectedSequenceTarget = expectedSequenceTarget
        self.minimumObservedSequenceCount = minimumObservedSequenceCount
        self.minimumLeftSequenceCount = minimumLeftSequenceCount
        self.minimumRightSequenceCount = minimumRightSequenceCount
        self.minimumNoneSequenceCount = minimumNoneSequenceCount
        self.maximumMedianCallbackLatencyMilliseconds =
            maximumMedianCallbackLatencyMilliseconds
    }
}
