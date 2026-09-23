import Combine
import Foundation
import WheelDomain

public enum WheelAppStatus: String, Equatable, Sendable {
    case starting = "Starting"
    case disabled = "Disabled"
    case needsPermission = "Needs Permission"
    case ready = "Ready"
    case paused = "Paused"
    case error = "Error"
}

public struct WheelAppConfiguration: Equatable, Sendable {
    public var triggerType: TriggerType
    public var minimumHorizontalDistance: Double
    public var minimumDominanceRatio: Double

    public init(
        triggerType: TriggerType = .rightOption,
        minimumHorizontalDistance: Double = 80,
        minimumDominanceRatio: Double = 1.5
    ) {
        self.triggerType = triggerType
        self.minimumHorizontalDistance = minimumHorizontalDistance
        self.minimumDominanceRatio = minimumDominanceRatio
    }

    public var validationError: String? {
        guard triggerType != .mouseSideButton else {
            return "Mouse side-button input is still an experimental diagnostic candidate."
        }
        guard minimumHorizontalDistance.isFinite,
              (20...500).contains(minimumHorizontalDistance)
        else {
            return "Gesture distance must be between 20 and 500 points."
        }
        guard minimumDominanceRatio.isFinite,
              (1...10).contains(minimumDominanceRatio)
        else {
            return "Horizontal dominance must be between 1 and 10."
        }

        return nil
    }
}

public enum WheelAppFixture: String, CaseIterable, Sendable {
    case disabled
    case needsPermission = "needs-permission"
    case ready
    case triggerHeld = "trigger-held"
    case paused
    case error

    public static func requested(from arguments: [String]) -> Self? {
        if let fixtureArgument = arguments.first(where: { $0.hasPrefix("--fixture=") }) {
            return Self(
                rawValue: String(fixtureArgument.dropFirst("--fixture=".count))
            )
        }

        guard let index = arguments.firstIndex(of: "--fixture") else {
            return nil
        }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }

        return Self(rawValue: arguments[valueIndex])
    }
}

/// Runtime state for the first production-facing Wheel menu-bar shell.
///
/// This view model owns only input readiness and gesture feedback. Context capture
/// and restoration remain outside this slice, so recognizing a gesture never
/// mutates `ContextHistory` or claims that navigation occurred.
@MainActor
public final class WheelAppViewModel: ObservableObject {
    public typealias PermissionProvider = () -> Bool
    public typealias PermissionRequester = () -> Bool
    public typealias MonitorFactory = (
        GlobalInputMonitor.Configuration
    ) -> any InputEventMonitoring

    @Published public private(set) var status: WheelAppStatus
    @Published public private(set) var permissionGranted: Bool
    @Published public private(set) var isEnabled: Bool
    @Published public private(set) var isPaused: Bool
    @Published public private(set) var isGestureActive: Bool
    @Published public private(set) var lastDirection: Direction?
    @Published public private(set) var recognizedGestureCount: Int
    @Published public private(set) var matchingTriggerSignalCount: Int
    @Published public private(set) var lastTriggerSignalIsDown: Bool?
    @Published public private(set) var eventTapRecoveryCount: Int
    @Published public private(set) var notice: String?
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var configuration: WheelAppConfiguration
    @Published public private(set) var overlayState: WheelGestureOverlayState
    /// Last visible payload, retained while the panel fades after becoming hidden.
    @Published public private(set) var overlayContentState: WheelGestureOverlayState

    public let fixture: WheelAppFixture?
    public let overlayFixture: WheelGestureOverlayFixture?

    private let permissionProvider: PermissionProvider
    private let permissionRequester: PermissionRequester
    private let monitorFactory: MonitorFactory
    private let overlayResultDuration: TimeInterval
    private let overlayDismissScheduler: WheelOverlayDismissScheduler
    private var monitor: (any InputEventMonitoring)?
    private var monitorGeneration = 0
    private var hasStarted = false
    private var overlayGeneration = 0
    private var overlayDismissAction: WheelOverlayScheduledAction?

    public init(
        configuration: WheelAppConfiguration = .init(),
        isEnabled: Bool = true,
        permissionProvider: @escaping PermissionProvider = {
            InputMonitoringPermission.isGranted
        },
        permissionRequester: @escaping PermissionRequester = {
            InputMonitoringPermission.request()
        },
        monitorFactory: @escaping MonitorFactory = {
            GlobalInputMonitor(configuration: $0)
        },
        fixture: WheelAppFixture? = nil,
        overlayFixture: WheelGestureOverlayFixture? = nil,
        overlayResultDuration: TimeInterval = 0.5,
        overlayDismissScheduler: WheelOverlayDismissScheduler = .mainQueue
    ) {
        precondition(overlayResultDuration >= 0)

        let effectiveFixture = fixture ?? (overlayFixture == nil ? nil : .ready)
        self.configuration = configuration
        self.isEnabled = isEnabled
        self.permissionProvider = permissionProvider
        self.permissionRequester = permissionRequester
        self.monitorFactory = monitorFactory
        self.fixture = effectiveFixture
        self.overlayFixture = overlayFixture
        self.overlayResultDuration = overlayResultDuration
        self.overlayDismissScheduler = overlayDismissScheduler

        let granted = effectiveFixture == nil
            ? permissionProvider()
            : effectiveFixture != .needsPermission
        permissionGranted = granted
        isPaused = false
        isGestureActive = false
        lastDirection = nil
        recognizedGestureCount = 0
        matchingTriggerSignalCount = 0
        lastTriggerSignalIsDown = nil
        eventTapRecoveryCount = 0
        notice = nil
        errorMessage = nil
        overlayState = .hidden
        overlayContentState = .hidden
        status = isEnabled
            ? (granted ? .starting : .needsPermission)
            : .disabled

        applyFixtureIfNeeded()
    }

    public var isMonitoring: Bool {
        monitor?.isRunning == true
    }

    public var canPause: Bool {
        fixture == nil && isEnabled && !isPaused && status == .ready
    }

    public var canResume: Bool {
        fixture == nil && isEnabled && isPaused
    }

    public var canRequestPermission: Bool {
        fixture == nil && isEnabled && !permissionGranted
    }

    public func start() {
        guard fixture == nil else { return }

        hasStarted = true
        reconcileRuntime()
    }

    public func refreshPermission() {
        guard fixture == nil else { return }

        permissionGranted = permissionProvider()
        reconcileRuntime()
    }

    public func requestPermission() {
        guard canRequestPermission else { return }

        permissionGranted = permissionRequester() || permissionProvider()
        reconcileRuntime()
    }

    public func setEnabled(_ enabled: Bool) {
        guard fixture == nil else { return }

        isEnabled = enabled
        if enabled {
            isPaused = false
        }
        reconcileRuntime()
    }

    public func pause() {
        guard canPause else { return }

        isPaused = true
        stopMonitor()
        status = .paused
        errorMessage = nil
        notice = "Wheel is paused. No global input is being observed."
    }

    public func resume() {
        guard canResume else { return }

        isPaused = false
        notice = nil
        reconcileRuntime()
    }

    public func updateConfiguration(_ configuration: WheelAppConfiguration) {
        guard fixture == nil, configuration != self.configuration else { return }

        self.configuration = configuration
        errorMessage = configuration.validationError

        guard hasStarted, isEnabled, !isPaused, permissionGranted else {
            reconcileStatusWithoutStarting()
            return
        }

        stopMonitor()
        startMonitorIfPossible()
    }

    public func handleSystemWake() {
        guard fixture == nil, hasStarted, isEnabled, !isPaused else { return }

        stopMonitor()
        permissionGranted = permissionProvider()
        notice = "Wheel refreshed input monitoring after your Mac woke up."
        reconcileRuntime(preservingNotice: true)
    }

    public func shutdown() {
        guard fixture == nil else { return }

        hasStarted = false
        stopMonitor()
    }

    private func reconcileRuntime(preservingNotice: Bool = false) {
        guard isEnabled else {
            stopMonitor()
            isPaused = false
            status = .disabled
            errorMessage = nil
            if !preservingNotice {
                notice = "Wheel is off. No global input is being observed."
            }
            return
        }

        guard permissionGranted else {
            stopMonitor()
            status = .needsPermission
            errorMessage = nil
            if !preservingNotice {
                notice = nil
            }
            return
        }

        guard !isPaused else {
            stopMonitor()
            status = .paused
            errorMessage = nil
            return
        }

        guard hasStarted else {
            status = .starting
            return
        }

        if !preservingNotice {
            notice = nil
        }
        startMonitorIfPossible()
    }

    private func reconcileStatusWithoutStarting() {
        if !isEnabled {
            status = .disabled
        } else if !permissionGranted {
            status = .needsPermission
        } else if isPaused {
            status = .paused
        } else if let validationError = configuration.validationError {
            status = .error
            errorMessage = validationError
        } else {
            status = .starting
        }
    }

    private func startMonitorIfPossible() {
        guard monitor == nil else {
            if monitor?.isRunning == true {
                status = .ready
            }
            return
        }

        if let validationError = configuration.validationError {
            status = .error
            errorMessage = validationError
            return
        }

        let classifier = HorizontalGestureClassifier(
            minimumHorizontalDistance: configuration.minimumHorizontalDistance,
            minimumDominanceRatio: configuration.minimumDominanceRatio
        )
        let newMonitor = monitorFactory(
            .init(
                triggerType: configuration.triggerType,
                classifier: classifier
            )
        )

        monitorGeneration += 1
        let generation = monitorGeneration
        newMonitor.onEvent = { [weak self] event in
            DispatchQueue.main.async { [weak self] in
                self?.handle(event, generation: generation)
            }
        }
        monitor = newMonitor

        do {
            try newMonitor.start()
            status = .ready
            errorMessage = nil
        } catch {
            stopMonitor()
            status = .error
            errorMessage = error.localizedDescription
        }
    }

    private func handle(_ event: GlobalInputEvent, generation: Int) {
        guard generation == monitorGeneration, status == .ready else { return }

        switch event {
        case .callbackObserved, .pointerMoved:
            break

        case let .modifierSignal(_, sampledDown, _):
            matchingTriggerSignalCount += 1
            lastTriggerSignalIsDown = sampledDown

        case let .mouseButtonSignal(_, isDown, matchesConfiguredButton):
            guard matchesConfiguredButton else { return }
            matchingTriggerSignalCount += 1
            lastTriggerSignalIsDown = isDown

        case .triggerBegan:
            guard !isGestureActive else { return }
            isGestureActive = true
            presentOverlay(.triggerHeld)
            notice = "Gesture active — move left or right, then release."

        case let .triggerEnded(direction, _, _):
            guard isGestureActive else { return }
            isGestureActive = false
            lastDirection = direction
            presentOverlayResult(direction)

            if direction == .none {
                notice = "Movement was too short or not horizontal enough."
            } else {
                recognizedGestureCount += 1
                notice = "\(direction.rawValue.uppercased()) recognized. "
                    + "Context restoration is not connected in this build yet."
            }

        case .eventTapRecovered:
            isGestureActive = false
            lastTriggerSignalIsDown = nil
            hideOverlay()
            eventTapRecoveryCount += 1
            notice = "Input monitoring recovered and cleared transient gesture state."
        }
    }

    private func stopMonitor() {
        monitorGeneration += 1
        monitor?.onEvent = nil
        monitor?.stop()
        monitor = nil
        isGestureActive = false
        lastTriggerSignalIsDown = nil
        hideOverlay()
    }

    private func applyFixtureIfNeeded() {
        guard let fixture else { return }

        hasStarted = false
        overlayState = .hidden
        overlayContentState = .hidden
        isGestureActive = false
        lastDirection = nil
        recognizedGestureCount = 0
        matchingTriggerSignalCount = 0
        lastTriggerSignalIsDown = nil
        eventTapRecoveryCount = 0

        switch fixture {
        case .disabled:
            isEnabled = false
            permissionGranted = true
            isPaused = false
            status = .disabled
            notice = "Wheel is off. No global input is being observed."
        case .needsPermission:
            isEnabled = true
            permissionGranted = false
            isPaused = false
            status = .needsPermission
            notice = nil
        case .ready:
            isEnabled = true
            permissionGranted = true
            isPaused = false
            status = .ready
            lastDirection = .left
            recognizedGestureCount = 12
            matchingTriggerSignalCount = 2
            lastTriggerSignalIsDown = false
            notice = "LEFT recognized. Context restoration is not connected in this build yet."
        case .triggerHeld:
            isEnabled = true
            permissionGranted = true
            isPaused = false
            isGestureActive = true
            overlayState = .triggerHeld
            overlayContentState = .triggerHeld
            status = .ready
            matchingTriggerSignalCount = 1
            lastTriggerSignalIsDown = true
            notice = "Gesture active — move left or right, then release."
        case .paused:
            isEnabled = true
            permissionGranted = true
            isPaused = true
            status = .paused
            notice = "Wheel is paused. No global input is being observed."
        case .error:
            isEnabled = true
            permissionGranted = true
            isPaused = false
            status = .error
            errorMessage = "macOS could not create the listen-only event tap."
            notice = nil
        }

        applyOverlayFixtureIfNeeded()
    }

    private func applyOverlayFixtureIfNeeded() {
        guard let overlayFixture else { return }

        status = .ready
        overlayState = overlayFixture.state
        overlayContentState = overlayFixture.state
        isGestureActive = overlayFixture == .held
        matchingTriggerSignalCount = overlayFixture == .held ? 1 : 2
        lastTriggerSignalIsDown = overlayFixture == .held

        switch overlayFixture {
        case .held:
            lastDirection = nil
            recognizedGestureCount = 0
            notice = "Gesture active — move left or right, then release."
        case .left:
            lastDirection = .left
            recognizedGestureCount = 1
            notice = "LEFT recognized. Context restoration is not connected in this build yet."
        case .right:
            lastDirection = .right
            recognizedGestureCount = 1
            notice = "RIGHT recognized. Context restoration is not connected in this build yet."
        case .none:
            lastDirection = Direction.none
            recognizedGestureCount = 0
            notice = "Movement was too short or not horizontal enough."
        }
    }

    private func presentOverlay(_ state: WheelGestureOverlayState) {
        overlayDismissAction?.cancel()
        overlayDismissAction = nil
        overlayGeneration += 1
        overlayContentState = state
        overlayState = state
    }

    private func presentOverlayResult(_ direction: Direction) {
        let resultState: WheelGestureOverlayState
        switch direction {
        case .left:
            resultState = .resultLeft
        case .right:
            resultState = .resultRight
        case .none:
            resultState = .resultNone
        }

        presentOverlay(resultState)
        let generation = overlayGeneration
        overlayDismissAction = overlayDismissScheduler.schedule(
            after: overlayResultDuration
        ) { [weak self] in
            guard let self, self.overlayGeneration == generation else { return }

            self.overlayDismissAction = nil
            self.overlayState = .hidden
        }
    }

    private func hideOverlay() {
        overlayDismissAction?.cancel()
        overlayDismissAction = nil
        overlayGeneration += 1
        overlayState = .hidden
    }
}
