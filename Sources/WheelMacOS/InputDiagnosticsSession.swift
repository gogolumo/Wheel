import Foundation
import WheelDomain

public enum InputDiagnosticsStatus: String, Equatable, Sendable {
    case permissionRequired = "Permission Required"
    case ready = "Ready"
    case listening = "Listening"
    case triggerHeld = "Trigger Held"
    case completed = "Completed"
    case stopped = "Stopped"
    case eventTapRecovered = "Event Tap Recovered"
    case error = "Error"
}

public struct InputDiagnosticsConfiguration: Equatable, Sendable {
    public var runLabel: String
    public var triggerType: TriggerType
    public var targetSequenceCount: Int
    public var minimumHorizontalDistance: Double
    public var minimumDominanceRatio: Double
    public var mouseButtonNumber: Int64

    public init(
        runLabel: String = "diagnostics-run",
        triggerType: TriggerType = .rightOption,
        targetSequenceCount: Int = 30,
        minimumHorizontalDistance: Double = 80,
        minimumDominanceRatio: Double = 1.5,
        mouseButtonNumber: Int64 = 3
    ) {
        self.runLabel = runLabel
        self.triggerType = triggerType
        self.targetSequenceCount = targetSequenceCount
        self.minimumHorizontalDistance = minimumHorizontalDistance
        self.minimumDominanceRatio = minimumDominanceRatio
        self.mouseButtonNumber = mouseButtonNumber
    }

    public var validationError: String? {
        if let error = InputEvidenceRunLabel.validationError(for: runLabel) {
            return error
        }
        guard (1...10_000).contains(targetSequenceCount) else {
            return "Sequence target must be between 1 and 10,000."
        }
        guard minimumHorizontalDistance.isFinite,
              (1...5_000).contains(minimumHorizontalDistance)
        else {
            return "Minimum horizontal distance must be between 1 and 5,000 points."
        }
        guard minimumDominanceRatio.isFinite,
              (1...100).contains(minimumDominanceRatio)
        else {
            return "Dominance ratio must be between 1 and 100."
        }
        guard (3...31).contains(mouseButtonNumber) else {
            return "Mouse side-button number must be between 3 and 31."
        }

        return nil
    }
}

public enum InputDiagnosticsSessionAction: Equatable, Sendable {
    case none
    case stopMonitoring
}

public enum InputDiagnosticsSessionError: Error, Equatable, LocalizedError {
    case permissionRequired
    case invalidConfiguration(String)
    case resetRequired
    case evidenceUnavailable

    public var errorDescription: String? {
        switch self {
        case .permissionRequired:
            return "Input Monitoring permission is required."
        case let .invalidConfiguration(message):
            return message
        case .resetRequired:
            return "Reset the current run before starting another one."
        case .evidenceUnavailable:
            return "Stop or complete the run before exporting evidence."
        }
    }
}

/// Pure state machine shared by the diagnostics UI and deterministic tests.
///
/// It stores aggregate measurements only. Pointer coordinates, key history,
/// window metadata, file paths, and other private event data never enter this type.
public struct InputDiagnosticsSession: Equatable, Sendable {
    public private(set) var permissionGranted: Bool
    public private(set) var status: InputDiagnosticsStatus
    public private(set) var configuration: InputDiagnosticsConfiguration
    public private(set) var statistics: InputSpikeRunStatistics
    public private(set) var lastDirection: Direction?
    public private(set) var completionReason: InputSpikeRunSummary.CompletionReason?
    public private(set) var evidenceSaved: Bool
    public private(set) var errorMessage: String?
    public private(set) var notice: String?
    public private(set) var isListening: Bool
    public private(set) var triggerIsHeld: Bool

    public init(
        permissionGranted: Bool,
        configuration: InputDiagnosticsConfiguration = .init()
    ) {
        self.permissionGranted = permissionGranted
        status = permissionGranted ? .ready : .permissionRequired
        self.configuration = configuration
        statistics = InputSpikeRunStatistics()
        lastDirection = nil
        completionReason = nil
        evidenceSaved = false
        errorMessage = nil
        notice = nil
        isListening = false
        triggerIsHeld = false
    }

    public var evidenceAvailable: Bool {
        completionReason != nil
    }

    public mutating func updatePermission(_ granted: Bool) {
        permissionGranted = granted

        guard granted else {
            if isListening || triggerIsHeld {
                completionReason = .interrupted
            }
            isListening = false
            triggerIsHeld = false
            status = .permissionRequired
            errorMessage = nil
            notice = "Monitoring stopped because Input Monitoring is unavailable."
            return
        }

        if status == .permissionRequired {
            status = evidenceAvailable ? .stopped : .ready
            notice = nil
        }
    }

    public mutating func start(
        configuration: InputDiagnosticsConfiguration
    ) throws {
        guard permissionGranted else {
            status = .permissionRequired
            throw InputDiagnosticsSessionError.permissionRequired
        }
        if let validationError = configuration.validationError {
            throw InputDiagnosticsSessionError.invalidConfiguration(validationError)
        }
        guard !evidenceAvailable,
              statistics.completedSequenceCount == 0,
              !isListening
        else {
            throw InputDiagnosticsSessionError.resetRequired
        }

        self.configuration = configuration
        status = .listening
        isListening = true
        triggerIsHeld = false
        lastDirection = nil
        evidenceSaved = false
        errorMessage = nil
        notice = nil
    }

    @discardableResult
    public mutating func handle(
        _ event: GlobalInputEvent
    ) -> InputDiagnosticsSessionAction {
        guard isListening else {
            return .none
        }

        switch event {
        case let .callbackObserved(latencyMilliseconds):
            statistics.recordCallbackLatency(milliseconds: latencyMilliseconds)

        case .modifierSignal, .mouseButtonSignal:
            break

        case .triggerBegan:
            guard !triggerIsHeld else {
                return .none
            }
            triggerIsHeld = true
            status = .triggerHeld
            notice = nil

        case .pointerMoved:
            guard triggerIsHeld else {
                return .none
            }
            statistics.recordPointerMovement()

        case let .triggerEnded(direction, _, _):
            guard triggerIsHeld else {
                return .none
            }

            triggerIsHeld = false
            statistics.recordCompletedSequence(direction: direction)
            lastDirection = direction

            if statistics.completedSequenceCount >= configuration.targetSequenceCount {
                isListening = false
                completionReason = .targetReached
                status = .completed
                return .stopMonitoring
            }

            status = .listening

        case .eventTapRecovered:
            triggerIsHeld = false
            statistics.recordEventTapRecovery()
            status = .eventTapRecovered
            notice = "Transient input state was cleared. Verify the next physical sequence."
        }

        return .none
    }

    public mutating func stop() {
        guard status != .completed else {
            return
        }

        isListening = false
        triggerIsHeld = false
        completionReason = .interrupted
        evidenceSaved = false
        status = .stopped
        errorMessage = nil
    }

    public mutating func interruptAfterSystemWake() {
        stop()
        notice = "Stopped after wake to prevent a stale held-trigger state. Start a new run."
    }

    public mutating func reset(permissionGranted: Bool) {
        self = InputDiagnosticsSession(
            permissionGranted: permissionGranted,
            configuration: configuration
        )
    }

    public mutating func markEvidenceSaved() {
        guard evidenceAvailable else {
            return
        }
        evidenceSaved = true
        errorMessage = nil
        if status == .error {
            status = completionReason == .targetReached ? .completed : .stopped
        }
    }

    public mutating func fail(_ message: String) {
        if isListening || triggerIsHeld {
            completionReason = .interrupted
        }
        isListening = false
        triggerIsHeld = false
        status = .error
        errorMessage = message
    }

    public mutating func failToStart(_ message: String) {
        isListening = false
        triggerIsHeld = false
        completionReason = nil
        evidenceSaved = false
        status = .error
        errorMessage = message
    }

    public func makeSummary() throws -> InputSpikeRunSummary {
        guard let completionReason else {
            throw InputDiagnosticsSessionError.evidenceUnavailable
        }

        return InputSpikeRunSummary(
            runLabel: configuration.runLabel,
            trigger: configuration.triggerType,
            minimumHorizontalDistance: configuration.minimumHorizontalDistance,
            minimumDominanceRatio: configuration.minimumDominanceRatio,
            mouseButtonNumber: configuration.triggerType == .mouseSideButton
                ? configuration.mouseButtonNumber
                : nil,
            sequenceTarget: configuration.targetSequenceCount,
            statistics: statistics,
            completionReason: completionReason
        )
    }
}
