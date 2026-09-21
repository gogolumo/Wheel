import XCTest
import WheelDomain
@testable import WheelMacOS

final class WheelAppViewModelTests: XCTestCase {
    func testMissingPermissionDoesNotCreateMonitor() async {
        await MainActor.run {
            var factoryCallCount = 0
            let viewModel = WheelAppViewModel(
                permissionProvider: { false },
                permissionRequester: { false },
                monitorFactory: { _ in
                    factoryCallCount += 1
                    return AppTestInputMonitor()
                }
            )

            viewModel.start()

            XCTAssertEqual(viewModel.status, .needsPermission)
            XCTAssertFalse(viewModel.permissionGranted)
            XCTAssertFalse(viewModel.isMonitoring)
            XCTAssertEqual(factoryCallCount, 0)
        }
    }

    func testStartCreatesListenOnlyMonitorAndBecomesReady() async {
        await MainActor.run {
            let monitor = AppTestInputMonitor()
            var capturedConfiguration: GlobalInputMonitor.Configuration?
            let viewModel = WheelAppViewModel(
                configuration: .init(
                    triggerType: .rightOption,
                    minimumHorizontalDistance: 120,
                    minimumDominanceRatio: 2
                ),
                permissionProvider: { true },
                permissionRequester: { true },
                monitorFactory: {
                    capturedConfiguration = $0
                    return monitor
                }
            )

            viewModel.start()

            XCTAssertEqual(viewModel.status, .ready)
            XCTAssertTrue(viewModel.isMonitoring)
            XCTAssertEqual(monitor.startCallCount, 1)
            XCTAssertEqual(capturedConfiguration?.triggerType, .rightOption)
            XCTAssertEqual(
                capturedConfiguration?.classifier.minimumHorizontalDistance,
                120
            )
            XCTAssertEqual(
                capturedConfiguration?.classifier.minimumDominanceRatio,
                2
            )
        }
    }

    func testPauseStopsMonitoringAndResumeCreatesFreshMonitor() async {
        await MainActor.run {
            let firstMonitor = AppTestInputMonitor()
            let secondMonitor = AppTestInputMonitor()
            var monitors = [firstMonitor, secondMonitor]
            let viewModel = WheelAppViewModel(
                permissionProvider: { true },
                permissionRequester: { true },
                monitorFactory: { _ in monitors.removeFirst() }
            )
            viewModel.start()

            viewModel.pause()

            XCTAssertEqual(viewModel.status, .paused)
            XCTAssertFalse(viewModel.isMonitoring)
            XCTAssertEqual(firstMonitor.stopCallCount, 1)

            viewModel.resume()

            XCTAssertEqual(viewModel.status, .ready)
            XCTAssertTrue(viewModel.isMonitoring)
            XCTAssertEqual(secondMonitor.startCallCount, 1)
        }
    }

    func testRecognizedGestureUpdatesFeedbackWithoutClaimingNavigation() async {
        let feedbackUpdated = expectation(description: "gesture feedback updated")

        await MainActor.run {
            let monitor = AppTestInputMonitor()
            let viewModel = WheelAppViewModel(
                permissionProvider: { true },
                permissionRequester: { true },
                monitorFactory: { _ in monitor }
            )
            viewModel.start()

            monitor.emit(.triggerBegan(origin: .init(x: 100, y: 100)))
            monitor.emit(
                .triggerEnded(
                    direction: .left,
                    displacement: .init(horizontal: -120, vertical: 4),
                    duration: 0.2
                )
            )

            DispatchQueue.main.async {
                XCTAssertFalse(viewModel.isGestureActive)
                XCTAssertEqual(viewModel.lastDirection, .left)
                XCTAssertEqual(viewModel.recognizedGestureCount, 1)
                XCTAssertEqual(viewModel.status, .ready)
                XCTAssertTrue(
                    viewModel.notice?.contains("restoration is not connected") == true
                )
                feedbackUpdated.fulfill()
            }
        }

        await fulfillment(of: [feedbackUpdated], timeout: 1)
    }

    func testQueuedEventFromReplacedMonitorIsIgnored() async {
        let queueDrained = expectation(description: "main queue drained")

        await MainActor.run {
            let firstMonitor = AppTestInputMonitor()
            let secondMonitor = AppTestInputMonitor()
            var monitors = [firstMonitor, secondMonitor]
            let viewModel = WheelAppViewModel(
                permissionProvider: { true },
                permissionRequester: { true },
                monitorFactory: { _ in monitors.removeFirst() }
            )
            viewModel.start()

            firstMonitor.emit(.triggerBegan(origin: .init(x: 0, y: 0)))
            viewModel.updateConfiguration(
                .init(
                    triggerType: .rightOption,
                    minimumHorizontalDistance: 140,
                    minimumDominanceRatio: 1.5
                )
            )

            DispatchQueue.main.async {
                XCTAssertFalse(viewModel.isGestureActive)
                XCTAssertNil(viewModel.lastDirection)
                XCTAssertTrue(secondMonitor.isRunning)
                XCTAssertEqual(firstMonitor.stopCallCount, 1)
                queueDrained.fulfill()
            }
        }

        await fulfillment(of: [queueDrained], timeout: 1)
    }

    func testMonitorStartFailureIsVisibleAndNeverClaimsReady() async {
        await MainActor.run {
            let monitor = AppTestInputMonitor(startError: AppTestMonitorError.startFailed)
            let viewModel = WheelAppViewModel(
                permissionProvider: { true },
                permissionRequester: { true },
                monitorFactory: { _ in monitor }
            )

            viewModel.start()

            XCTAssertEqual(viewModel.status, .error)
            XCTAssertFalse(viewModel.isMonitoring)
            XCTAssertEqual(monitor.stopCallCount, 1)
            XCTAssertEqual(viewModel.errorMessage, "Test monitor failed to start.")
        }
    }

    func testFixtureDoesNotConsultPermissionOrCreateMonitor() async {
        await MainActor.run {
            var permissionCheckCount = 0
            var factoryCallCount = 0
            let viewModel = WheelAppViewModel(
                permissionProvider: {
                    permissionCheckCount += 1
                    return false
                },
                permissionRequester: { false },
                monitorFactory: { _ in
                    factoryCallCount += 1
                    return AppTestInputMonitor()
                },
                fixture: .ready
            )

            viewModel.start()
            viewModel.refreshPermission()

            XCTAssertEqual(permissionCheckCount, 0)
            XCTAssertEqual(factoryCallCount, 0)
            XCTAssertEqual(viewModel.status, .ready)
            XCTAssertEqual(viewModel.lastDirection, .left)
            XCTAssertEqual(viewModel.recognizedGestureCount, 12)
        }
    }
}

private enum AppTestMonitorError: LocalizedError {
    case startFailed

    var errorDescription: String? {
        "Test monitor failed to start."
    }
}

private final class AppTestInputMonitor: InputEventMonitoring {
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
