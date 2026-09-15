import Combine
import Foundation

public protocol InputEventMonitoring: AnyObject {
    var onEvent: ((GlobalInputEvent) -> Void)? { get set }
    var isRunning: Bool { get }

    func start() throws
    func stop()
}

extension GlobalInputMonitor: InputEventMonitoring {}

@MainActor
public final class InputDiagnosticsViewModel: ObservableObject {
    public typealias PermissionProvider = () -> Bool
    public typealias PermissionRequester = () -> Bool
    public typealias MonitorFactory = (
        GlobalInputMonitor.Configuration
    ) -> any InputEventMonitoring

    @Published public var configuration: InputDiagnosticsConfiguration
    @Published public private(set) var session: InputDiagnosticsSession

    private let permissionProvider: PermissionProvider
    private let permissionRequester: PermissionRequester
    private let monitorFactory: MonitorFactory
    private var monitor: (any InputEventMonitoring)?

    public init(
        configuration: InputDiagnosticsConfiguration = .init(),
        permissionProvider: @escaping PermissionProvider = {
            InputMonitoringPermission.isGranted
        },
        permissionRequester: @escaping PermissionRequester = {
            InputMonitoringPermission.request()
        },
        monitorFactory: @escaping MonitorFactory = {
            GlobalInputMonitor(configuration: $0)
        }
    ) {
        self.configuration = configuration
        self.permissionProvider = permissionProvider
        self.permissionRequester = permissionRequester
        self.monitorFactory = monitorFactory
        session = InputDiagnosticsSession(
            permissionGranted: permissionProvider(),
            configuration: configuration
        )
    }

    public var configurationLocked: Bool {
        session.isListening || session.evidenceAvailable
    }

    public var canStart: Bool {
        session.permissionGranted
            && !configurationLocked
            && configuration.validationError == nil
    }

    public var canStop: Bool {
        session.isListening
    }

    public var canReset: Bool {
        session.isListening
            || session.evidenceAvailable
            || session.statistics.completedSequenceCount > 0
            || session.status == .error
            || session.status == .eventTapRecovered
    }

    public var canExport: Bool {
        session.evidenceAvailable
    }

    public var suggestedEvidenceFilename: String {
        let label = session.configuration.runLabel
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        return "wheel-input-\(label).json"
    }

    public func refreshPermission() {
        let granted = permissionProvider()
        if !granted {
            stopMonitor()
        }

        var nextSession = session
        nextSession.updatePermission(granted)
        session = nextSession
    }

    public func requestPermission() {
        let granted = permissionRequester() || permissionProvider()
        if !granted {
            stopMonitor()
        }

        var nextSession = session
        nextSession.updatePermission(granted)
        session = nextSession
    }

    public func startListening() {
        refreshPermission()
        guard session.permissionGranted else {
            return
        }

        var nextSession = session
        do {
            try nextSession.start(configuration: configuration)
        } catch {
            nextSession.failToStart(error.localizedDescription)
            session = nextSession
            return
        }
        session = nextSession

        let classifier = HorizontalGestureClassifier(
            minimumHorizontalDistance: configuration.minimumHorizontalDistance,
            minimumDominanceRatio: configuration.minimumDominanceRatio
        )
        let newMonitor = monitorFactory(
            .init(
                triggerType: configuration.triggerType,
                classifier: classifier,
                mouseButtonNumber: configuration.mouseButtonNumber
            )
        )
        newMonitor.onEvent = { [weak self] event in
            DispatchQueue.main.async { [weak self] in
                self?.handle(event)
            }
        }
        monitor = newMonitor

        do {
            try newMonitor.start()
        } catch {
            stopMonitor()
            var failedSession = session
            failedSession.failToStart(error.localizedDescription)
            session = failedSession
        }
    }

    public func stopAndPreparePartialEvidence() throws -> Data {
        stopMonitor()
        var nextSession = session
        nextSession.stop()
        session = nextSession
        return try session.makeSummary().encodedJSON()
    }

    public func exportEvidenceData() throws -> Data {
        try session.makeSummary().encodedJSON()
    }

    public func markEvidenceSaved() {
        var nextSession = session
        nextSession.markEvidenceSaved()
        session = nextSession
    }

    public func reportExportError(_ error: Error) {
        var nextSession = session
        nextSession.fail("Unable to save evidence: \(error.localizedDescription)")
        session = nextSession
    }

    public func reset() {
        stopMonitor()
        var nextSession = session
        nextSession.reset(permissionGranted: permissionProvider())
        session = nextSession
    }

    public func handleSystemWake() {
        guard session.isListening || session.triggerIsHeld else {
            return
        }

        stopMonitor()
        var nextSession = session
        nextSession.interruptAfterSystemWake()
        session = nextSession
    }

    public func shutdown() {
        stopMonitor()
        guard session.isListening || session.triggerIsHeld else {
            return
        }

        var nextSession = session
        nextSession.stop()
        session = nextSession
    }

    private func handle(_ event: GlobalInputEvent) {
        var nextSession = session
        let action = nextSession.handle(event)
        session = nextSession

        if action == .stopMonitoring {
            stopMonitor()
        }
    }

    private func stopMonitor() {
        monitor?.onEvent = nil
        monitor?.stop()
        monitor = nil
    }
}
