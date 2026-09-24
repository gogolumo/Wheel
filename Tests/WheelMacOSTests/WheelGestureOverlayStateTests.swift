import XCTest
import WheelDomain
@testable import WheelMacOS

final class WheelGestureOverlayStateTests: XCTestCase {
    func testOverlayFixtureArgumentsSupportNamedAndEqualsForms() {
        XCTAssertEqual(
            WheelGestureOverlayFixture.requested(
                from: ["wheel-app", "--overlay-fixture", "held"]
            ),
            .held
        )
        XCTAssertEqual(
            WheelGestureOverlayFixture.requested(
                from: ["wheel-app", "--overlay-fixture=right"]
            ),
            .right
        )
        XCTAssertNil(
            WheelGestureOverlayFixture.requested(
                from: ["wheel-app", "--overlay-fixture"]
            )
        )
        XCTAssertNil(
            WheelGestureOverlayFixture.requested(
                from: ["wheel-app", "--overlay-fixture=unknown"]
            )
        )
    }

    func testTriggerBeginDelaysHeldOverlayUntilThreshold() async {
        let harness = await makeHarness()

        await MainActor.run {
            harness.monitor.emit(.triggerBegan(origin: .init(x: 10, y: 20)))
        }
        await drainMainQueue()

        await MainActor.run {
            XCTAssertEqual(harness.viewModel.overlayState, .hidden)
            XCTAssertTrue(harness.viewModel.isGestureActive)
            XCTAssertEqual(harness.scheduler.pendingActions.count, 1)
            XCTAssertEqual(harness.scheduler.pendingActions.first?.delay, 0.18)

            harness.scheduler.runPendingActions()

            XCTAssertEqual(harness.viewModel.overlayState, .triggerHeld)
            XCTAssertTrue(harness.viewModel.overlayState.isVisible)
        }
    }

    func testRepeatedTriggerBeginIsIdempotent() async {
        let harness = await makeHarness()

        await MainActor.run {
            harness.monitor.emit(.triggerBegan(origin: .init(x: 0, y: 0)))
            harness.monitor.emit(.triggerBegan(origin: .init(x: 5, y: 5)))
        }
        await drainMainQueue()

        await MainActor.run {
            XCTAssertEqual(harness.viewModel.overlayState, .hidden)
            XCTAssertTrue(harness.viewModel.isGestureActive)
            XCTAssertEqual(harness.scheduler.pendingActions.count, 1)

            harness.scheduler.runPendingActions()

            XCTAssertEqual(harness.viewModel.overlayState, .triggerHeld)
        }
    }

    func testReleaseBeforeThresholdNeverPresentsOverlayOrResult() async {
        let harness = await makeHarness()

        await MainActor.run {
            harness.monitor.emit(.triggerBegan(origin: .init(x: 0, y: 0)))
            harness.monitor.emit(
                .triggerEnded(
                    direction: .right,
                    displacement: .init(horizontal: 120, vertical: 0),
                    duration: 0.1
                )
            )
        }
        await drainMainQueue()

        await MainActor.run {
            XCTAssertEqual(harness.viewModel.overlayState, .hidden)
            XCTAssertFalse(harness.viewModel.isGestureActive)
            XCTAssertEqual(harness.viewModel.lastDirection, .right)
            XCTAssertEqual(harness.viewModel.recognizedGestureCount, 1)

            harness.scheduler.runPendingActions()

            XCTAssertEqual(harness.viewModel.overlayState, .hidden)
        }
    }

    func testReleaseShowsLeftRightAndNoneResults() async {
        let harness = await makeHarness()

        await emitGesture(.left, harness: harness)
        await MainActor.run {
            XCTAssertEqual(harness.viewModel.overlayState, .resultLeft)
        }

        await emitGesture(.right, harness: harness)
        await MainActor.run {
            XCTAssertEqual(harness.viewModel.overlayState, .resultRight)
        }

        await emitGesture(.none, harness: harness)
        await MainActor.run {
            XCTAssertEqual(harness.viewModel.overlayState, .resultNone)
        }
    }

    func testResultAutoHidesThroughInjectedScheduler() async {
        let harness = await makeHarness()

        await emitGesture(.left, harness: harness)

        await MainActor.run {
            XCTAssertEqual(harness.viewModel.overlayState, .resultLeft)
            XCTAssertEqual(harness.scheduler.pendingActions.count, 1)
            XCTAssertEqual(harness.scheduler.pendingActions.first?.delay, 0.5)
            harness.scheduler.runPendingActions()
            XCTAssertEqual(harness.viewModel.overlayState, .hidden)
            XCTAssertEqual(harness.viewModel.overlayContentState, .resultLeft)
        }
    }

    func testNewTriggerCancelsPreviousDelayedHide() async {
        let harness = await makeHarness()

        await emitGesture(.left, harness: harness)
        await MainActor.run {
            harness.monitor.emit(.triggerBegan(origin: .init(x: 0, y: 0)))
        }
        await drainMainQueue()

        await MainActor.run {
            XCTAssertEqual(harness.viewModel.overlayState, .hidden)
            harness.scheduler.runPendingActions()
            XCTAssertEqual(harness.viewModel.overlayState, .triggerHeld)
        }
    }

    func testDuplicateTriggerEndDoesNotScheduleAnotherResult() async {
        let harness = await makeHarness()

        await emitGesture(.left, harness: harness)
        await MainActor.run {
            harness.monitor.emit(
                .triggerEnded(
                    direction: .right,
                    displacement: .init(horizontal: 120, vertical: 0),
                    duration: 0.2
                )
            )
        }
        await drainMainQueue()

        await MainActor.run {
            XCTAssertEqual(harness.viewModel.overlayState, .resultLeft)
            XCTAssertEqual(harness.viewModel.lastDirection, .left)
            XCTAssertEqual(harness.scheduler.pendingActions.count, 1)
        }
    }

    func testPauseHidesHeldOverlay() async {
        let harness = await makeHarness()
        await beginGesture(harness)

        await MainActor.run {
            harness.viewModel.pause()
            XCTAssertEqual(harness.viewModel.overlayState, .hidden)
        }
    }

    func testPauseBeforeThresholdCancelsPendingPresentation() async {
        let harness = await makeHarness()

        await MainActor.run {
            harness.monitor.emit(.triggerBegan(origin: .init(x: 0, y: 0)))
        }
        await drainMainQueue()

        await MainActor.run {
            XCTAssertEqual(harness.viewModel.overlayState, .hidden)
            harness.viewModel.pause()
            harness.scheduler.runPendingActions()

            XCTAssertEqual(harness.viewModel.overlayState, .hidden)
            XCTAssertEqual(harness.viewModel.status, .paused)
        }
    }

    func testDisableHidesHeldOverlay() async {
        let harness = await makeHarness()
        await beginGesture(harness)

        await MainActor.run {
            harness.viewModel.setEnabled(false)
            XCTAssertEqual(harness.viewModel.overlayState, .hidden)
        }
    }

    func testPermissionLossHidesHeldOverlay() async {
        let permission = PermissionBox(granted: true)
        let harness = await makeHarness(permission: permission)
        await beginGesture(harness)

        await MainActor.run {
            permission.granted = false
            harness.viewModel.refreshPermission()
            XCTAssertEqual(harness.viewModel.overlayState, .hidden)
            XCTAssertEqual(harness.viewModel.status, .needsPermission)
        }
    }

    func testRecoveryHidesHeldOverlay() async {
        let harness = await makeHarness()

        await MainActor.run {
            harness.monitor.emit(.triggerBegan(origin: .init(x: 0, y: 0)))
            harness.monitor.emit(.eventTapRecovered)
        }
        await drainMainQueue()

        await MainActor.run {
            XCTAssertEqual(harness.viewModel.overlayState, .hidden)
            XCTAssertFalse(harness.viewModel.isGestureActive)
            harness.scheduler.runPendingActions()
            XCTAssertEqual(harness.viewModel.overlayState, .hidden)
        }
    }

    func testConfigurationChangeAndWakeHideHeldOverlay() async {
        let harness = await makeHarness()
        await beginGesture(harness)

        await MainActor.run {
            harness.viewModel.updateConfiguration(
                .init(
                    triggerType: .rightOption,
                    minimumHorizontalDistance: 100,
                    minimumDominanceRatio: 1.5
                )
            )
            XCTAssertEqual(harness.viewModel.overlayState, .hidden)
        }

        await beginGesture(harness)
        await MainActor.run {
            harness.viewModel.handleSystemWake()
            XCTAssertEqual(harness.viewModel.overlayState, .hidden)
        }
    }

    func testShutdownHidesHeldOverlay() async {
        let harness = await makeHarness()
        await beginGesture(harness)

        await MainActor.run {
            harness.viewModel.shutdown()
            XCTAssertEqual(harness.viewModel.overlayState, .hidden)
        }
    }

    func testUnmatchedModifierSignalDoesNotShowOverlay() async {
        let harness = await makeHarness()

        await MainActor.run {
            harness.monitor.emit(
                .modifierSignal(
                    keyCode: 58,
                    sampledDown: true,
                    alphaShiftEnabled: false
                )
            )
        }
        await drainMainQueue()

        await MainActor.run {
            XCTAssertEqual(harness.viewModel.overlayState, .hidden)
            XCTAssertFalse(harness.viewModel.isGestureActive)
        }
    }

    func testOverlayFixtureNeverCreatesMonitor() async {
        await MainActor.run {
            var monitorCreationCount = 0
            let viewModel = WheelAppViewModel(
                permissionProvider: { false },
                permissionRequester: { false },
                monitorFactory: { _ in
                    monitorCreationCount += 1
                    return OverlayTestInputMonitor()
                },
                overlayFixture: .held
            )

            viewModel.start()
            viewModel.refreshPermission()

            XCTAssertEqual(monitorCreationCount, 0)
            XCTAssertEqual(viewModel.status, .ready)
            XCTAssertEqual(viewModel.overlayState, .triggerHeld)
            XCTAssertTrue(viewModel.isGestureActive)
        }
    }

    func testExistingTriggerHeldFixtureAlsoShowsProductionOverlay() async {
        await MainActor.run {
            let viewModel = WheelAppViewModel(fixture: .triggerHeld)

            XCTAssertEqual(viewModel.overlayState, .triggerHeld)
            XCTAssertTrue(viewModel.isGestureActive)
        }
    }

    func testDirectionOverlayFixturesExposeMatchingResultState() async {
        await MainActor.run {
            let right = WheelAppViewModel(overlayFixture: .right)
            let none = WheelAppViewModel(
                overlayFixture: WheelGestureOverlayFixture.none
            )

            XCTAssertEqual(right.overlayState, .resultRight)
            XCTAssertEqual(right.lastDirection, .right)
            XCTAssertEqual(right.recognizedGestureCount, 1)
            XCTAssertFalse(right.isGestureActive)

            XCTAssertEqual(none.overlayState, .resultNone)
            XCTAssertEqual(none.lastDirection, Direction.none)
            XCTAssertEqual(none.recognizedGestureCount, 0)
            XCTAssertFalse(none.isGestureActive)
        }
    }

    private func makeHarness(
        permission: PermissionBox = PermissionBox(granted: true)
    ) async -> OverlayHarness {
        await MainActor.run {
            OverlayHarness(permission: permission)
        }
    }

    private func beginGesture(_ harness: OverlayHarness) async {
        await MainActor.run {
            harness.monitor.emit(.triggerBegan(origin: .init(x: 0, y: 0)))
        }
        await drainMainQueue()
        await MainActor.run {
            harness.scheduler.runPendingActions()
        }
    }

    private func emitGesture(
        _ direction: Direction,
        harness: OverlayHarness
    ) async {
        await beginGesture(harness)
        await MainActor.run {
            harness.monitor.emit(
                .triggerEnded(
                    direction: direction,
                    displacement: .init(
                        horizontal: direction == .left ? -120 : 120,
                        vertical: 0
                    ),
                    duration: 0.2
                )
            )
        }
        await drainMainQueue()
    }

    private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }
}

private struct OverlayHarness: @unchecked Sendable {
    let viewModel: WheelAppViewModel
    let monitor: OverlayTestInputMonitor
    let scheduler: ManualOverlayDismissScheduler

    @MainActor
    init(permission: PermissionBox) {
        let monitor = OverlayTestInputMonitor()
        let scheduler = ManualOverlayDismissScheduler()
        self.monitor = monitor
        self.scheduler = scheduler
        viewModel = WheelAppViewModel(
            permissionProvider: { permission.granted },
            permissionRequester: { permission.granted },
            monitorFactory: { _ in monitor },
            overlayDismissScheduler: scheduler.scheduler
        )
        viewModel.start()
    }
}

private final class PermissionBox: @unchecked Sendable {
    var granted: Bool

    init(granted: Bool) {
        self.granted = granted
    }
}

@MainActor
private final class ManualOverlayDismissScheduler {
    struct PendingAction {
        let delay: TimeInterval
        let token: WheelOverlayScheduledAction
        let action: () -> Void
    }

    private(set) var pendingActions: [PendingAction] = []

    var scheduler: WheelOverlayDismissScheduler {
        WheelOverlayDismissScheduler { [weak self] delay, action in
            let token = WheelOverlayScheduledAction()
            self?.pendingActions.append(
                .init(delay: delay, token: token, action: action)
            )
            return token
        }
    }

    func runPendingActions() {
        let actions = pendingActions
        pendingActions.removeAll()
        for pendingAction in actions where !pendingAction.token.isCancelled {
            pendingAction.action()
        }
    }
}

private final class OverlayTestInputMonitor: InputEventMonitoring {
    var onEvent: ((GlobalInputEvent) -> Void)?
    private(set) var isRunning = false

    func start() throws {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    func emit(_ event: GlobalInputEvent) {
        onEvent?(event)
    }
}
