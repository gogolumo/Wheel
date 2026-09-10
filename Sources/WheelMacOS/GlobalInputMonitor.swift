import ApplicationServices
import Foundation
import WheelDomain

public enum InputMonitoringPermission {
    public static var isGranted: Bool {
        CGPreflightListenEventAccess()
    }

    @discardableResult
    public static func request() -> Bool {
        CGRequestListenEventAccess()
    }
}

public enum GlobalInputMonitorError: Error, Equatable {
    case alreadyRunning
    case unsupportedTrigger(TriggerType)
    case eventTapUnavailable
}

public struct PointerPosition: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum GlobalInputEvent {
    case callbackObserved(latencyMilliseconds: Double)
    case modifierSignal(
        keyCode: Int64,
        sampledDown: Bool,
        alphaShiftEnabled: Bool
    )
    case mouseButtonSignal(
        buttonNumber: Int64,
        isDown: Bool,
        matchesConfiguredButton: Bool
    )
    case triggerBegan(origin: PointerPosition)
    case pointerMoved(displacement: PointerDisplacement)
    case triggerEnded(
        direction: Direction,
        displacement: PointerDisplacement,
        duration: TimeInterval
    )
    case eventTapRecovered
}

/// Listen-only diagnostic monitor for the M1 feasibility spike.
///
/// This type observes input but never suppresses, rewrites, or posts an event.
/// It intentionally uses public macOS APIs so the spike can give an honest
/// GO / ADJUST / STOP result for the proposed trigger.
public final class GlobalInputMonitor {
    public struct Configuration: Sendable {
        public let triggerType: TriggerType
        public let classifier: HorizontalGestureClassifier
        public let keyPollingInterval: TimeInterval
        public let mouseButtonNumber: Int64

        public init(
            triggerType: TriggerType = .capsLock,
            classifier: HorizontalGestureClassifier = .init(),
            keyPollingInterval: TimeInterval = 1.0 / 120.0,
            mouseButtonNumber: Int64 = 3
        ) {
            precondition(keyPollingInterval > 0)
            precondition(mouseButtonNumber >= 3)

            self.triggerType = triggerType
            self.classifier = classifier
            self.keyPollingInterval = keyPollingInterval
            self.mouseButtonNumber = mouseButtonNumber
        }
    }

    public var onEvent: ((GlobalInputEvent) -> Void)?

    public private(set) var isRunning = false

    private let configuration: Configuration
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pollingTimer: Timer?

    private var triggerIsDown = false
    private var origin: PointerPosition?
    private var latestPosition: PointerPosition?
    private var triggerStartedAt: TimeInterval?
    private var mouseButtonState: MouseButtonTriggerState

    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
        mouseButtonState = MouseButtonTriggerState(
            buttonNumber: configuration.mouseButtonNumber
        )
    }

    deinit {
        stop()
    }

    public func start() throws {
        guard !isRunning else {
            throw GlobalInputMonitorError.alreadyRunning
        }

        if configuration.triggerType != .mouseSideButton {
            _ = try keyCode(for: configuration.triggerType)
        }

        let eventTypes: [CGEventType] = [
            .flagsChanged,
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged,
            .otherMouseDown,
            .otherMouseUp
        ]
        let mask = eventTypes.reduce(CGEventMask(0)) { partialResult, eventType in
            partialResult | (CGEventMask(1) << CGEventMask(eventType.rawValue))
        }

        let callback: CGEventTapCallBack = { _, eventType, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let monitor = Unmanaged<GlobalInputMonitor>
                .fromOpaque(userInfo)
                .takeUnretainedValue()
            return monitor.handle(eventType: eventType, event: event)
        }

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw GlobalInputMonitorError.eventTapUnavailable
        }

        guard let runLoopSource = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            eventTap,
            0
        ) else {
            CFMachPortInvalidate(eventTap)
            throw GlobalInputMonitorError.eventTapUnavailable
        }

        self.eventTap = eventTap
        self.runLoopSource = runLoopSource

        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        if configuration.triggerType != .mouseSideButton {
            let timer = Timer(
                timeInterval: configuration.keyPollingInterval,
                repeats: true
            ) { [weak self] _ in
                self?.sampleTriggerState()
            }
            pollingTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }

        isRunning = true
        sampleTriggerState()
    }

    public func stop() {
        pollingTimer?.invalidate()
        pollingTimer = nil

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        self.runLoopSource = nil

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        self.eventTap = nil

        isRunning = false
        mouseButtonState.reset()
        resetGestureState()
    }

    private func handle(
        eventType: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
                if configuration.triggerType == .mouseSideButton {
                    mouseButtonState.reset()
                    resetGestureState()
                }
                onEvent?(.eventTapRecovered)
            }
            return Unmanaged.passUnretained(event)
        }

        if eventType == .flagsChanged {
            let eventKeyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let selectedKeyCode = try? keyCode(for: configuration.triggerType)

            if
                let selectedKeyCode,
                eventKeyCode == Int64(selectedKeyCode)
            {
                let sampledDown = CGEventSource.keyState(
                    .combinedSessionState,
                    key: selectedKeyCode
                )
                let alphaShiftEnabled = event.flags.contains(.maskAlphaShift)

                if let latencyMilliseconds = callbackLatencyMilliseconds(for: event) {
                    onEvent?(.callbackObserved(latencyMilliseconds: latencyMilliseconds))
                }

                onEvent?(
                    .modifierSignal(
                        keyCode: eventKeyCode,
                        sampledDown: sampledDown,
                        alphaShiftEnabled: alphaShiftEnabled
                    )
                )
                sampleTriggerState()
            }
        } else if eventType == .otherMouseDown || eventType == .otherMouseUp {
            handleMouseButtonEvent(eventType: eventType, event: event)
        } else if isPointerEvent(eventType), triggerIsDown {
            if let latencyMilliseconds = callbackLatencyMilliseconds(for: event) {
                onEvent?(.callbackObserved(latencyMilliseconds: latencyMilliseconds))
            }
            recordPointerMovement(event.location)
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleMouseButtonEvent(
        eventType: CGEventType,
        event: CGEvent
    ) {
        guard configuration.triggerType == .mouseSideButton else {
            return
        }

        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        let isDown = eventType == .otherMouseDown
        let matchesConfiguredButton = mouseButtonState.matches(buttonNumber)

        onEvent?(
            .mouseButtonSignal(
                buttonNumber: buttonNumber,
                isDown: isDown,
                matchesConfiguredButton: matchesConfiguredButton
            )
        )

        guard matchesConfiguredButton else {
            return
        }

        if let latencyMilliseconds = callbackLatencyMilliseconds(for: event) {
            onEvent?(.callbackObserved(latencyMilliseconds: latencyMilliseconds))
        }

        guard
            let edge = mouseButtonState.consume(
                eventButtonNumber: buttonNumber,
                isDown: isDown
            )
        else {
            return
        }

        let position = PointerPosition(x: event.location.x, y: event.location.y)

        switch edge {
        case .pressed:
            beginGesture(at: position)
        case .released:
            latestPosition = position
            endGesture()
        }
    }

    private func callbackLatencyMilliseconds(for event: CGEvent) -> Double? {
        // CGEvent timestamps are expressed as nanoseconds since system startup,
        // which shares the monotonic uptime basis used by ProcessInfo here.
        let eventUptime = TimeInterval(event.timestamp) / 1_000_000_000
        let latency = (ProcessInfo.processInfo.systemUptime - eventUptime) * 1_000

        guard latency.isFinite, latency >= 0 else {
            return nil
        }

        return latency
    }

    private func sampleTriggerState() {
        guard configuration.triggerType != .mouseSideButton else {
            return
        }

        guard let keyCode = try? keyCode(for: configuration.triggerType) else {
            return
        }

        let sampledDown = CGEventSource.keyState(
            .combinedSessionState,
            key: keyCode
        )

        switch (triggerIsDown, sampledDown) {
        case (false, true):
            beginGesture()
        case (true, false):
            endGesture()
        case (false, false), (true, true):
            break
        }
    }

    private func beginGesture(at position: PointerPosition? = nil) {
        let currentPosition = position
            ?? CGEvent(source: nil)
                .map { PointerPosition(x: $0.location.x, y: $0.location.y) }
            ?? PointerPosition(x: 0, y: 0)

        triggerIsDown = true
        origin = currentPosition
        latestPosition = currentPosition
        triggerStartedAt = ProcessInfo.processInfo.systemUptime
        onEvent?(.triggerBegan(origin: currentPosition))
    }

    private func recordPointerMovement(_ point: CGPoint) {
        guard triggerIsDown, let origin else {
            return
        }

        let currentPosition = PointerPosition(x: point.x, y: point.y)
        latestPosition = currentPosition
        onEvent?(
            .pointerMoved(
                displacement: displacement(from: origin, to: currentPosition)
            )
        )
    }

    private func endGesture() {
        guard
            let origin,
            let latestPosition,
            let triggerStartedAt
        else {
            resetGestureState()
            return
        }

        let displacement = displacement(from: origin, to: latestPosition)
        let direction = configuration.classifier.classify(displacement)
        let duration = max(
            0,
            ProcessInfo.processInfo.systemUptime - triggerStartedAt
        )

        onEvent?(
            .triggerEnded(
                direction: direction,
                displacement: displacement,
                duration: duration
            )
        )
        resetGestureState()
    }

    private func resetGestureState() {
        triggerIsDown = false
        origin = nil
        latestPosition = nil
        triggerStartedAt = nil
    }

    private func displacement(
        from origin: PointerPosition,
        to currentPosition: PointerPosition
    ) -> PointerDisplacement {
        PointerDisplacement(
            horizontal: currentPosition.x - origin.x,
            vertical: currentPosition.y - origin.y
        )
    }

    private func isPointerEvent(_ eventType: CGEventType) -> Bool {
        switch eventType {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            return true
        default:
            return false
        }
    }

    private func keyCode(for triggerType: TriggerType) throws -> CGKeyCode {
        switch triggerType {
        case .capsLock:
            return 57
        case .rightOption:
            return 61
        case .mouseSideButton:
            throw GlobalInputMonitorError.unsupportedTrigger(.mouseSideButton)
        }
    }
}
