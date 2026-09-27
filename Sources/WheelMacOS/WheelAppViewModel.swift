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

/// Runtime state for Wheel's menu-bar shell, global trigger handling, and
/// application-level context navigation.
///
/// Window/tab/file identity still belongs to the later adapter/capture milestones.
/// This slice intentionally uses only NSWorkspace application identity so every
/// captured destination can be restored honestly at APPLICATION_ONLY depth.
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
    @Published public private(set) var applicationHistory: [WheelApplicationContext]
    @Published public private(set) var hoveredApplicationIndex: Int?
    @Published public private(set) var selectedApplicationIndex: Int?
    @Published public private(set) var lastApplicationAction: String?

    public let fixture: WheelAppFixture?
    public let overlayFixture: WheelGestureOverlayFixture?
    public let settings: WheelSettings

    private let permissionProvider: PermissionProvider
    private let permissionRequester: PermissionRequester
    private let monitorFactory: MonitorFactory
    private let overlayPresentationDelay: TimeInterval
    private let overlayResultDuration: TimeInterval
    private let overlayDismissScheduler: WheelOverlayDismissScheduler
    private let applicationMonitor: any WheelApplicationMonitoring
    private let applicationActivator: any WheelApplicationActivating
    private let applicationHistoryStore: WheelApplicationHistoryStore

    private var monitor: (any InputEventMonitoring)?
    private var monitorGeneration = 0
    private var hasStarted = false
    private var isSystemSleeping = false
    private var overlayGeneration = 0
    private var overlayPresentationAction: WheelOverlayScheduledAction?
    private var overlayDismissAction: WheelOverlayScheduledAction?
    private var historyCancellable: AnyCancellable?
    private var settingsCancellable: AnyCancellable?
    private var suppressedActivationIdentifier: String?
    private var suppressedActivationDeadline: Date?

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
        overlayPresentationDelay: TimeInterval = 0.18,
        overlayResultDuration: TimeInterval = 0.5,
        overlayDismissScheduler: WheelOverlayDismissScheduler = .mainQueue,
        settings: WheelSettings? = nil,
        applicationMonitor: (any WheelApplicationMonitoring)? = nil,
        applicationActivator: (any WheelApplicationActivating)? = nil,
        applicationHistoryStore: WheelApplicationHistoryStore? = nil
    ) {
        precondition(overlayPresentationDelay >= 0)
        precondition(overlayResultDuration >= 0)

        let effectiveFixture = fixture ?? (overlayFixture == nil ? nil : .ready)
        let settings = settings ?? WheelSettings()
        let historyStore = applicationHistoryStore ?? WheelApplicationHistoryStore()

        self.configuration = configuration
        self.isEnabled = isEnabled
        self.permissionProvider = permissionProvider
        self.permissionRequester = permissionRequester
        self.monitorFactory = monitorFactory
        self.fixture = effectiveFixture
        self.overlayFixture = overlayFixture
        self.overlayPresentationDelay = overlayPresentationDelay
        self.overlayResultDuration = overlayResultDuration
        self.overlayDismissScheduler = overlayDismissScheduler
        self.settings = settings
        self.applicationMonitor = applicationMonitor ?? WheelApplicationMonitor()
        self.applicationActivator = applicationActivator ?? WheelApplicationActivator()
        self.applicationHistoryStore = historyStore
        applicationHistory = historyStore.entries

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
        hoveredApplicationIndex = nil
        selectedApplicationIndex = nil
        lastApplicationAction = nil
        status = isEnabled
            ? (granted ? .starting : .needsPermission)
            : .disabled

        connectApplicationRuntime()
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

    public var wheelApplications: [WheelApplicationContext] {
        applicationHistoryStore.wheelEntries(
            limit: min(
                settings.visibleItemCount,
                settings.directionCount
            )
        )
    }

    public var displayedWheelItemLimit: Int {
        min(settings.visibleItemCount, settings.directionCount)
    }

    public func start() {
        guard fixture == nil else { return }

        hasStarted = true
        startApplicationCaptureIfNeeded()
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
            startApplicationCaptureIfNeeded()
        } else {
            applicationMonitor.stop()
        }
        reconcileRuntime()
    }

    public func pause() {
        guard canPause else { return }

        isPaused = true
        stopMonitor()
        status = .paused
        errorMessage = nil
        notice = "Wheel input is paused. Application history continues to update."
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

    public func setVisibleItemCount(_ value: Int) {
        settings.setVisibleItemCount(value)
        clearWheelSelection()
    }

    public func setDirectionCount(_ value: Int) {
        settings.setDirectionCount(value)
        clearWheelSelection()
    }

    public func setHistoryCapacity(_ value: Int) {
        settings.setHistoryCapacity(value)
        applicationHistoryStore.trim(to: settings.historyCapacity)
    }

    public func setRememberClosedApplications(_ value: Bool) {
        settings.setRememberClosedApplications(value)
    }

    public func handleSystemWake() {
        guard fixture == nil, hasStarted else { return }

        isSystemSleeping = false
        guard isEnabled, !isPaused else { return }

        stopMonitor()
        permissionGranted = permissionProvider()
        notice = "Wheel refreshed input monitoring after your Mac woke up."
        reconcileRuntime(preservingNotice: true)
    }

    public func handleSystemSleep() {
        guard fixture == nil, hasStarted else { return }

        let wasReady = status == .ready
        isSystemSleeping = true
        stopMonitor()

        guard wasReady else { return }

        status = .starting
        errorMessage = nil
        notice = "Wheel suspended input monitoring while your Mac sleeps."
    }

    public func shutdown() {
        guard fixture == nil else { return }

        hasStarted = false
        isSystemSleeping = false
        stopMonitor()
        applicationMonitor.stop()
        clearRestoreSuppression()
    }

    private func connectApplicationRuntime() {
        historyCancellable = applicationHistoryStore.$entries
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in
                self?.applicationHistory = entries
            }

        settingsCancellable = settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        applicationMonitor.onActivated = { [weak self] observation in
            self?.handleApplicationActivated(observation)
        }
        applicationMonitor.onLaunched = { [weak self] observation in
            self?.applicationHistoryStore.recordLaunch(observation)
        }
        applicationMonitor.onTerminated = { [weak self] observation in
            guard let self else { return }
            self.applicationHistoryStore.recordTermination(
                observation,
                rememberClosedApplications: self.settings.rememberClosedApplications
            )
        }
    }

    private func startApplicationCaptureIfNeeded() {
        guard hasStarted, isEnabled else { return }
        applicationMonitor.start()
    }

    private func handleApplicationActivated(
        _ observation: WheelObservedApplication
    ) {
        if shouldSuppressActivation(observation) {
            applicationHistoryStore.recordRestoredActivation(observation)
            clearRestoreSuppression()
            return
        }

        if suppressedActivationIdentifier != nil {
            clearRestoreSuppression()
        }

        applicationHistoryStore.recordActivation(
            observation,
            capacity: settings.historyCapacity
        )
    }

    private func shouldSuppressActivation(
        _ observation: WheelObservedApplication
    ) -> Bool {
        guard let expected = suppressedActivationIdentifier,
              let deadline = suppressedActivationDeadline
        else {
            return false
        }

        guard Date() <= deadline else {
            clearRestoreSuppression()
            return false
        }

        return expected == observation.stableIdentifier
    }

    private func beginRestoreSuppression(
        for context: WheelApplicationContext
    ) {
        suppressedActivationIdentifier = context.stableIdentifier
        suppressedActivationDeadline = Date().addingTimeInterval(2)
    }

    private func clearRestoreSuppression() {
        suppressedActivationIdentifier = nil
        suppressedActivationDeadline = nil
    }

    private func reconcileRuntime(preservingNotice: Bool = false) {
        guard isEnabled else {
            stopMonitor()
            isPaused = false
            status = .disabled
            errorMessage = nil
            if !preservingNotice {
                notice = "Wheel is off. Input and application capture are stopped."
            }
            return
        }

        guard permissionGranted else {
            stopMonitor()
            status = .needsPermission
            errorMessage = nil
            if !preservingNotice {
                notice = "Application history is active, but gesture input needs permission."
            }
            return
        }

        guard !isPaused else {
            stopMonitor()
            status = .paused
            errorMessage = nil
            return
        }

        guard !isSystemSleeping else {
            stopMonitor()
            status = .starting
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
        case .callbackObserved:
            break

        case let .pointerMoved(displacement):
            guard isGestureActive else { return }
            updateWheelSelection(displacement)

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
            clearWheelSelection()
            scheduleHeldOverlayPresentation()

            if wheelApplications.isEmpty {
                notice = "Gesture active — switch between a few apps first so Wheel has history."
            } else {
                notice = "Gesture active — move toward an application and release."
            }

        case let .triggerEnded(direction, displacement, _):
            guard isGestureActive else { return }
            isGestureActive = false
            lastDirection = direction

            let wasOverlayPresented = overlayState == .triggerHeld
            updateWheelSelection(displacement)

            if let index = hoveredApplicationIndex,
               wheelApplications.indices.contains(index)
            {
                selectedApplicationIndex = index
                recognizedGestureCount += 1
                let context = wheelApplications[index]
                lastApplicationAction = context.localizedName
                if wasOverlayPresented {
                    presentOverlay(.resultSelection)
                    scheduleOverlayDismissal()
                } else {
                    hideOverlay()
                }
                activateApplication(context)
            } else {
                selectedApplicationIndex = nil
                lastApplicationAction = nil
                if direction != .none {
                    recognizedGestureCount += 1
                }
                if wasOverlayPresented {
                    presentOverlayResult(direction)
                } else {
                    hideOverlay()
                }

                if wheelApplications.isEmpty {
                    notice = "No previous applications are available yet."
                } else {
                    notice = "No Wheel sector was selected."
                }
            }

        case .eventTapRecovered:
            isGestureActive = false
            lastTriggerSignalIsDown = nil
            clearWheelSelection()
            hideOverlay()
            eventTapRecoveryCount += 1
            notice = "Input monitoring recovered and cleared transient gesture state."
        }
    }

    private func updateWheelSelection(
        _ displacement: PointerDisplacement
    ) {
        let selected = WheelSectorLayout.selectedIndex(
            displacement: displacement,
            sectorCount: settings.directionCount,
            minimumDistance: configuration.minimumHorizontalDistance
        )

        guard let selected,
              wheelApplications.indices.contains(selected)
        else {
            hoveredApplicationIndex = nil
            return
        }

        hoveredApplicationIndex = selected
    }

    private func activateApplication(
        _ context: WheelApplicationContext
    ) {
        beginRestoreSuppression(for: context)

        let verb = context.runState == .running ? "Switching to" : "Reopening"
        notice = "\(verb) \(context.localizedName)…"

        applicationActivator.activate(context) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success:
                let verb = context.runState == .running ? "Switched to" : "Reopened"
                self.notice = "\(verb) \(context.localizedName)."
            case let .failure(error):
                self.clearRestoreSuppression()
                if context.runState != .running {
                    self.applicationHistoryStore.markUnavailable(context)
                }
                self.notice = error.localizedDescription
            }
        }
    }

    private func stopMonitor() {
        monitorGeneration += 1
        monitor?.onEvent = nil
        monitor?.stop()
        monitor = nil
        isGestureActive = false
        lastTriggerSignalIsDown = nil
        clearWheelSelection()
        hideOverlay()
    }

    private func clearWheelSelection() {
        hoveredApplicationIndex = nil
        selectedApplicationIndex = nil
        lastApplicationAction = nil
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
        clearWheelSelection()

        switch fixture {
        case .disabled:
            isEnabled = false
            permissionGranted = true
            isPaused = false
            status = .disabled
            notice = "Wheel is off. Input and application capture are stopped."
        case .needsPermission:
            isEnabled = true
            permissionGranted = false
            isPaused = false
            status = .needsPermission
            notice = "Application history is available without Input Monitoring permission."
        case .ready:
            isEnabled = true
            permissionGranted = true
            isPaused = false
            status = .ready
            lastDirection = .left
            recognizedGestureCount = 12
            matchingTriggerSignalCount = 2
            lastTriggerSignalIsDown = false
            notice = "Wheel is ready. Application capture is connected."
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
            notice = "Gesture active — move toward an application and release."
        case .paused:
            isEnabled = true
            permissionGranted = true
            isPaused = true
            status = .paused
            notice = "Wheel input is paused. Application history continues to update."
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
            notice = "Gesture active — move toward an application and release."
        case .left:
            lastDirection = .left
            recognizedGestureCount = 1
            notice = "LEFT recognized."
        case .right:
            lastDirection = .right
            recognizedGestureCount = 1
            notice = "RIGHT recognized."
        case .none:
            lastDirection = Direction.none
            recognizedGestureCount = 0
            notice = "Movement was too short or no Wheel sector was selected."
        }
    }

    private func presentOverlay(_ state: WheelGestureOverlayState) {
        overlayPresentationAction?.cancel()
        overlayPresentationAction = nil
        overlayDismissAction?.cancel()
        overlayDismissAction = nil
        overlayGeneration += 1
        overlayContentState = state
        overlayState = state
    }

    private func scheduleHeldOverlayPresentation() {
        hideOverlay()
        let generation = overlayGeneration
        overlayPresentationAction = overlayDismissScheduler.schedule(
            after: overlayPresentationDelay
        ) { [weak self] in
            guard let self,
                  self.overlayGeneration == generation,
                  self.isGestureActive,
                  self.status == .ready
            else {
                return
            }

            self.overlayPresentationAction = nil
            self.overlayContentState = .triggerHeld
            self.overlayState = .triggerHeld
        }
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
        scheduleOverlayDismissal()
    }

    private func scheduleOverlayDismissal() {
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
        overlayPresentationAction?.cancel()
        overlayPresentationAction = nil
        overlayDismissAction?.cancel()
        overlayDismissAction = nil
        overlayGeneration += 1
        overlayState = .hidden
    }
}
