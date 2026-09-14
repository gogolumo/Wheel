import Foundation
import WheelDomain

/// Privacy-safe, machine-readable evidence emitted by the disposable input spike.
/// Manual observations remain outside this type so partial telemetry cannot become an automatic GO.
public struct InputSpikeRunSummary: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let runLabel: String
    public let trigger: String
    public let minimumHorizontalDistance: Double
    public let minimumDominanceRatio: Double
    public let mouseButtonNumber: Int64?
    public let sequenceTarget: Int
    public let completedSequenceCount: Int
    public let leftCount: Int
    public let rightCount: Int
    public let noneCount: Int
    public let pointerMovementCount: Int
    public let callbackSampleCount: Int
    public let medianCallbackLatencyMilliseconds: Double?
    public let eventTapRecoveryCount: Int
    public let observedTargetMet: Bool
    public let latencyThresholdMilliseconds: Double
    public let latencyThresholdMet: Bool?
    public let requiresManualReview: Bool

    public init(
        runLabel: String,
        trigger: TriggerType,
        minimumHorizontalDistance: Double,
        minimumDominanceRatio: Double,
        mouseButtonNumber: Int64? = nil,
        sequenceTarget: Int,
        statistics: InputSpikeRunStatistics,
        latencyThresholdMilliseconds: Double = 25
    ) {
        precondition(minimumHorizontalDistance > 0)
        precondition(minimumDominanceRatio >= 1)
        precondition(mouseButtonNumber.map { $0 >= 3 } ?? true)
        precondition((trigger == .mouseSideButton) == (mouseButtonNumber != nil))
        precondition(sequenceTarget > 0)
        precondition(latencyThresholdMilliseconds > 0)
        schemaVersion = 2
        self.runLabel = runLabel
        self.trigger = trigger.rawValue
        self.minimumHorizontalDistance = minimumHorizontalDistance
        self.minimumDominanceRatio = minimumDominanceRatio
        self.mouseButtonNumber = mouseButtonNumber
        self.sequenceTarget = sequenceTarget
        completedSequenceCount = statistics.completedSequenceCount
        leftCount = statistics.leftCount
        rightCount = statistics.rightCount
        noneCount = statistics.noneCount
        pointerMovementCount = statistics.pointerMovementCount
        callbackSampleCount = statistics.callbackSampleCount
        medianCallbackLatencyMilliseconds = statistics.medianCallbackLatencyMilliseconds
        eventTapRecoveryCount = statistics.eventTapRecoveryCount
        observedTargetMet = statistics.completedSequenceCount >= sequenceTarget
        self.latencyThresholdMilliseconds = latencyThresholdMilliseconds
        latencyThresholdMet = statistics.medianCallbackLatencyMilliseconds.map {
            $0 < latencyThresholdMilliseconds
        }
        requiresManualReview = true
    }

    public func encodedJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}
