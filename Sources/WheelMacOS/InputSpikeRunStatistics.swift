import WheelDomain

/// Small, privacy-safe aggregate used by the input feasibility harness.
///
/// It deliberately stores no event coordinates, key contents, window titles,
/// application identities, or hardware identifiers.
public struct InputSpikeRunStatistics: Equatable, Sendable {
    public private(set) var completedSequenceCount = 0
    public private(set) var leftCount = 0
    public private(set) var rightCount = 0
    public private(set) var noneCount = 0
    public private(set) var eventTapRecoveryCount = 0

    private var callbackLatenciesMilliseconds: [Double] = []

    public init() {}

    public var callbackSampleCount: Int {
        callbackLatenciesMilliseconds.count
    }

    public var medianCallbackLatencyMilliseconds: Double? {
        guard !callbackLatenciesMilliseconds.isEmpty else {
            return nil
        }

        let sorted = callbackLatenciesMilliseconds.sorted()
        let middle = sorted.count / 2

        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }

        return sorted[middle]
    }

    public mutating func recordCompletedSequence(direction: Direction) {
        completedSequenceCount += 1

        switch direction {
        case .left:
            leftCount += 1
        case .right:
            rightCount += 1
        case .none:
            noneCount += 1
        }
    }

    public mutating func recordCallbackLatency(milliseconds: Double) {
        guard milliseconds.isFinite, milliseconds >= 0 else {
            return
        }

        callbackLatenciesMilliseconds.append(milliseconds)
    }

    public mutating func recordEventTapRecovery() {
        eventTapRecoveryCount += 1
    }
}
