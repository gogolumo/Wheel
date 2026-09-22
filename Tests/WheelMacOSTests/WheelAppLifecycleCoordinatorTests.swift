import XCTest
@testable import WheelMacOS

final class WheelAppLifecycleCoordinatorTests: XCTestCase {
    func testLaunchesOnceAndTerminatesOnce() async {
        await MainActor.run {
            let monitor = LifecycleTestInputMonitor()
            let viewModel = WheelAppViewModel(
                permissionProvider: { true },
                permissionRequester: { true },
                monitorFactory: { _ in monitor }
            )
            let coordinator = WheelAppLifecycleCoordinator(viewModel: viewModel)

            coordinator.launch()
            coordinator.launch()

            XCTAssertTrue(coordinator.hasLaunched)
            XCTAssertEqual(viewModel.status, .ready)
            XCTAssertEqual(monitor.startCallCount, 1)

            coordinator.terminate()
            coordinator.terminate()

            XCTAssertFalse(coordinator.hasLaunched)
            XCTAssertFalse(viewModel.isMonitoring)
            XCTAssertEqual(monitor.stopCallCount, 1)
        }
    }

    func testRefreshesPermissionOnlyAfterLaunch() async {
        await MainActor.run {
            let monitor = LifecycleTestInputMonitor()
            var permissionGranted = true
            var permissionCheckCount = 0
            let viewModel = WheelAppViewModel(
                permissionProvider: {
                    permissionCheckCount += 1
                    return permissionGranted
                },
                permissionRequester: { permissionGranted },
                monitorFactory: { _ in monitor }
            )
            let coordinator = WheelAppLifecycleCoordinator(viewModel: viewModel)

            coordinator.applicationDidBecomeActive()
            XCTAssertEqual(permissionCheckCount, 1)

            coordinator.launch()
            permissionGranted = false
            coordinator.applicationDidBecomeActive()

            XCTAssertEqual(permissionCheckCount, 2)
            XCTAssertEqual(viewModel.status, .needsPermission)
            XCTAssertFalse(viewModel.isMonitoring)
            XCTAssertEqual(monitor.stopCallCount, 1)
        }
    }

    func testReplacesMonitorAfterWake() async {
        await MainActor.run {
            let firstMonitor = LifecycleTestInputMonitor()
            let secondMonitor = LifecycleTestInputMonitor()
            var monitors = [firstMonitor, secondMonitor]
            let viewModel = WheelAppViewModel(
                permissionProvider: { true },
                permissionRequester: { true },
                monitorFactory: { _ in monitors.removeFirst() }
            )
            let coordinator = WheelAppLifecycleCoordinator(viewModel: viewModel)

            coordinator.launch()
            coordinator.systemDidWake()

            XCTAssertEqual(firstMonitor.stopCallCount, 1)
            XCTAssertEqual(secondMonitor.startCallCount, 1)
            XCTAssertTrue(viewModel.isMonitoring)
            XCTAssertEqual(viewModel.status, .ready)
            XCTAssertEqual(
                viewModel.notice,
                "Wheel refreshed input monitoring after your Mac woke up."
            )
        }
    }
}

private final class LifecycleTestInputMonitor: InputEventMonitoring {
    var onEvent: ((GlobalInputEvent) -> Void)?
    private(set) var isRunning = false
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    func start() throws {
        startCallCount += 1
        isRunning = true
    }

    func stop() {
        stopCallCount += 1
        isRunning = false
    }
}
