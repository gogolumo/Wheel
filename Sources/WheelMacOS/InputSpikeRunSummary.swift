import Foundation
import WheelDomain

/// Privacy-safe, machine-readable evidence emitted by the disposable input spike.
/// Manual observations remain outside this type so partial telemetry cannot become an automatic GO.
public struct InputSpikeRunSummary: Codable, Equatable, Sendable {
    public enum DocumentValidationError: Error, Equatable, Sendable {
        case topLevelObjectRequired
        case unsupportedFields
    }

    public enum CompletionReason: String, Codable, Equatable, Sendable {
        case targetReached
        case interrupted
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case runLabel
        case trigger
        case minimumHorizontalDistance
        case minimumDominanceRatio
        case mouseButtonNumber
        case sequenceTarget
        case completedSequenceCount
        case leftCount
        case rightCount
        case noneCount
        case pointerMovementCount
        case callbackSampleCount
        case medianCallbackLatencyMilliseconds
        case eventTapRecoveryCount
        case completionReason
        case observedTargetMet
        case latencyThresholdMilliseconds
        case latencyThresholdMet
        case requiresManualReview
    }

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
    public let completionReason: CompletionReason
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
        completionReason: CompletionReason,
        latencyThresholdMilliseconds: Double = 25
    ) {
        precondition(minimumHorizontalDistance > 0)
        precondition(minimumDominanceRatio >= 1)
        precondition(mouseButtonNumber.map { $0 >= 3 } ?? true)
        precondition((trigger == .mouseSideButton) == (mouseButtonNumber != nil))
        precondition(sequenceTarget > 0)
        precondition(latencyThresholdMilliseconds > 0)
        schemaVersion = 3
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
        self.completionReason = completionReason
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

    /// Decodes an evidence export only when its top-level fields match the
    /// privacy-reviewed schema. `JSONDecoder` normally ignores unknown fields,
    /// which could otherwise allow unapproved data to travel with valid
    /// aggregate evidence unnoticed.
    public static func decodeValidatedJSON(_ data: Data) throws -> Self {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let fields = object as? [String: Any] else {
            throw DocumentValidationError.topLevelObjectRequired
        }

        let allowedFields = Set(CodingKeys.allCases.map(\.rawValue))
        guard Set(fields.keys).isSubset(of: allowedFields) else {
            throw DocumentValidationError.unsupportedFields
        }

        return try JSONDecoder().decode(Self.self, from: data)
    }
}
