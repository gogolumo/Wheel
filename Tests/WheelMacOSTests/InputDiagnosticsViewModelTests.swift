import XCTest
@testable import WheelMacOS

final class InputDiagnosticsViewModelTests: XCTestCase {
    func testMissingPermissionPreventsMonitorCreation() async {
        await MainActor.run {
            var factoryCallCount = 0
            let viewModel = InputDiagnosticsViewModel(
                permissionProvider: { false },
                permissionRequester: { false },
                monitorFactory: { _ in
                    factoryCallCount += 1
                    return TestInputMonitor()
                }
            )

            viewModel.startListening()

            XCTAssertFalse(viewModel.canStart)
            XCTAssertEqual(viewModel.session.status, .permissionRequired)
            XCTAssertEqual(factoryCallCount, 0)
        }
    }

    func testStartPassesValidatedConfigurationAndStartsMonitor() async {
        await MainActor.run {
            let monitor = TestInputMonitor()
            var capturedConfiguration: GlobalInputMonitor.Configuration?
            let configuration = InputDiagnosticsConfiguration(
                runLabel: "right-option-finder",
                triggerType: .rightOption,
                targetSequenceCount: 30,
                minimumHorizontalDistance: 120,
                minimumDominanceRatio: 2,
                mouseButtonNumber: 5
            )
            let viewModel = InputDiagnosticsViewModel(
                configuration: configuration,
                permissionProvider: { true },
                permissionRequester: { true },
                monitorFactory: {
                    capturedConfiguration = $0
                    return monitor
                }
            )

            viewModel.startListening()

            XCTAssertTrue(monitor.isRunning)
            XCTAssertEqual(monitor.startCallCount, 1)
            XCTAssertEqual(viewModel.session.status, .listening)
            XCTAssertEqual(capturedConfiguration?.triggerType, .rightOption)
            XCTAssertEqual(
                capturedConfiguration?.classifier.minimumHorizontalDistance,
                120
            )
            XCTAssertEqual(
                capturedConfiguration?.classifier.minimumDominanceRatio,
                2
            )
            XCTAssertEqual(capturedConfiguration?.mouseButtonNumber, 5)
        }
    }

    func testMonitorStartFailureDoesNotClaimListening() async {
        await MainActor.run {
            let monitor = TestInputMonitor(startError: TestMonitorError.startFailed)
            let viewModel = InputDiagnosticsViewModel(
                permissionProvider: { true },
                permissionRequester: { true },
                monitorFactory: { _ in monitor }
            )

            viewModel.startListening()

            XCTAssertFalse(monitor.isRunning)
            XCTAssertEqual(monitor.stopCallCount, 1)
            XCTAssertEqual(viewModel.session.status, .error)
            XCTAssertFalse(viewModel.session.isListening)
            XCTAssertNil(viewModel.session.completionReason)
            XCTAssertEqual(viewModel.session.errorMessage, "Test monitor failed to start.")
        }
    }

    func testResetStopsMonitorAndReturnsToReady() async {
        await MainActor.run {
            let monitor = TestInputMonitor()
            let viewModel = InputDiagnosticsViewModel(
                permissionProvider: { true },
                permissionRequester: { true },
                monitorFactory: { _ in monitor }
            )
            viewModel.startListening()

            viewModel.reset()

            XCTAssertFalse(monitor.isRunning)
            XCTAssertEqual(monitor.stopCallCount, 1)
            XCTAssertEqual(viewModel.session.status, .ready)
            XCTAssertFalse(viewModel.session.isListening)
            XCTAssertEqual(viewModel.session.statistics.completedSequenceCount, 0)
        }
    }

    func testQueuedEventsFromStoppedMonitorCannotContaminateNewRun() async {
        let queueDrained = expectation(description: "main queue drained")

        await MainActor.run {
            let firstMonitor = TestInputMonitor()
            let secondMonitor = TestInputMonitor()
            var monitors: [TestInputMonitor] = [firstMonitor, secondMonitor]
            let viewModel = InputDiagnosticsViewModel(
                permissionProvider: { true },
                permissionRequester: { true },
                monitorFactory: { _ in monitors.removeFirst() }
            )

            viewModel.startListening()
            firstMonitor.emit(.triggerBegan(origin: .init(x: 0, y: 0)))
            firstMonitor.emit(
                .triggerEnded(
                    direction: .left,
                    displacement: .init(horizontal: -100, vertical: 0),
                    duration: 0.1
                )
            )

            viewModel.reset()
            viewModel.startListening()

            DispatchQueue.main.async {
                XCTAssertEqual(viewModel.session.status, .listening)
                XCTAssertEqual(viewModel.session.statistics.completedSequenceCount, 0)
                XCTAssertNil(viewModel.session.lastDirection)
                XCTAssertTrue(secondMonitor.isRunning)
                queueDrained.fulfill()
            }
        }

        await fulfillment(of: [queueDrained], timeout: 1)
    }
}

private enum TestMonitorError: LocalizedError {
    case startFailed

    var errorDescription: String? {
        "Test monitor failed to start."
    }
}

private final class TestInputMonitor: InputEventMonitoring {
    var onEvent: ((GlobalInputEvent) -> Void)?
    private(set) var isRunning = false
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    private let startError: Error?

    init(startError: Error? = nil) {
        self.startError = startError
    }

    func start() throws {
        startCallCount += 1
        if let startError {
            throw startError
        }
        isRunning = true
    }

    func stop() {
        stopCallCount += 1
        isRunning = false
    }

    func emit(_ event: GlobalInputEvent) {
        onEvent?(event)
    }
}
