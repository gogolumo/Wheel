import Foundation
import XCTest
@testable import WheelMacOS

final class WheelVisualFixtureTests: XCTestCase {
    func testParserSupportsNamedAndEqualsOptionsAndRejectsInvalidInput() {
        for fixture in WheelVisualFixture.allCases {
            XCTAssertEqual(
                WheelVisualFixture.requested(from: ["wheel-app", "--visual-fixture", fixture.rawValue]),
                fixture
            )
            XCTAssertEqual(
                WheelVisualFixture.requested(from: ["wheel-app", "--visual-fixture=\(fixture.rawValue)"]),
                fixture
            )
        }
        XCTAssertNil(WheelVisualFixture.requested(from: ["wheel-app"]))
        XCTAssertNil(WheelVisualFixture.requested(from: ["wheel-app", "--visual-fixture"]))
        XCTAssertNil(WheelVisualFixture.requested(from: ["wheel-app", "--visual-fixture=unknown"]))
        XCTAssertNil(WheelVisualFixture.requested(from: ["wheel-app", "--visual-fixture", "unknown"]))
    }

    func testEqualsOptionHasSamePrecedenceAsLegacyParsers() {
        XCTAssertEqual(
            WheelVisualFixture.requested(from: ["wheel-app", "--visual-fixture", "two", "--visual-fixture=twelve"]),
            .twelve
        )
        XCTAssertEqual(
            WheelVisualFixture.requested(from: ["wheel-app", "--visual-fixture=four", "--visual-fixture=twelve"]),
            .four
        )
        XCTAssertNil(
            WheelVisualFixture.requested(from: ["wheel-app", "--visual-fixture", "two", "--visual-fixture=unknown"])
        )
    }

    func testVisualFixtureOverridesConflictingLegacyStates() async {
        await MainActor.run {
            let viewModel = WheelAppViewModel(
                fixture: .disabled,
                overlayFixture: .left,
                visualFixture: .selectedTerminated
            )

            XCTAssertEqual(viewModel.fixture, .ready)
            XCTAssertEqual(viewModel.visualFixture, .selectedTerminated)
            XCTAssertEqual(viewModel.status, .ready)
            XCTAssertTrue(viewModel.isEnabled)
            XCTAssertEqual(viewModel.overlayState, .resultSelection)
            XCTAssertNil(viewModel.lastDirection)
            XCTAssertEqual(viewModel.selectedApplicationIndex, 0)
            XCTAssertEqual(viewModel.wheelSlots[0]?.runState, .terminated)
            XCTAssertEqual(viewModel.fixtureLabel, "Synthetic visual fixture · selected-terminated")
        }
    }

    func testPopulationFixturesHaveExactCountsAndDeterministicIdentities() async {
        await MainActor.run {
            let fixtures: [(WheelVisualFixture, Int)] = [
                (.empty, 0), (.two, 2), (.four, 4), (.six, 6), (.eight, 8), (.twelve, 12)
            ]
            for (fixture, count) in fixtures {
                let first = WheelAppViewModel(visualFixture: fixture)
                let second = WheelAppViewModel(visualFixture: fixture)

                XCTAssertEqual(first.wheelApplications.count, count, fixture.rawValue)
                XCTAssertEqual(first.wheelSlots.count, fixture.directionCount)
                XCTAssertEqual(first.wheelSlots, second.wheelSlots)
                XCTAssertEqual(first.applicationHistory.count, count)
                XCTAssertTrue(first.pinnedSlots.slots.isEmpty)
                XCTAssertEqual(first.overlayState, .triggerHeld)
                XCTAssertEqual(first.overlayContentState, .triggerHeld)
                XCTAssertTrue(first.isGestureActive)
                XCTAssertNil(first.hoveredApplicationIndex)
                XCTAssertNil(first.selectedApplicationIndex)
                XCTAssertTrue(first.wheelApplications.allSatisfy {
                    $0.stableIdentifier.hasPrefix("fixture:")
                        && $0.localizedName.hasPrefix("Sample ")
                        && $0.bundleIdentifier == nil && $0.applicationURL == nil
                })
            }
        }
    }

    func testSelectedFixturesExposeRunningAndRecentlyClosedStates() async {
        await MainActor.run {
            for (fixture, state) in [
                (WheelVisualFixture.selectedRunning, WheelApplicationRunState.running),
                (.selectedTerminated, .terminated)
            ] {
                let viewModel = WheelAppViewModel(visualFixture: fixture)
                XCTAssertEqual(viewModel.wheelApplications.count, 6)
                XCTAssertEqual(viewModel.hoveredApplicationIndex, 0)
                XCTAssertEqual(viewModel.selectedApplicationIndex, 0)
                XCTAssertEqual(viewModel.wheelSlots[0]?.runState, state)
                XCTAssertEqual(viewModel.overlayState, .resultSelection)
                XCTAssertEqual(viewModel.lastApplicationAction, viewModel.wheelSlots[0]?.localizedName)
                XCTAssertFalse(viewModel.isGestureActive)
            }
        }
    }

    func testUnavailablePinStaysVisibleAndRetainsItsSectorAcrossReads() async {
        await MainActor.run {
            let viewModel = WheelAppViewModel(visualFixture: .unavailablePin)
            let firstSlots = viewModel.wheelSlots

            XCTAssertEqual(viewModel.applicationHistory.count, 5)
            XCTAssertEqual(viewModel.wheelApplications.count, 6)
            XCTAssertEqual(viewModel.pinnedSlots.slots.map(\.position), [2])
            XCTAssertTrue(viewModel.isPinnedSlot(2))
            XCTAssertEqual(firstSlots[2]?.runState, .unavailable)
            XCTAssertEqual(firstSlots[2]?.localizedName, "Sample Missing App")
            XCTAssertEqual(firstSlots, viewModel.wheelSlots)
            XCTAssertEqual(viewModel.hoveredApplicationIndex, 2)
            XCTAssertNil(viewModel.selectedApplicationIndex)
        }
    }

    func testMixedFixturePreservesFixedPinsAndUniqueDynamicSlots() async {
        await MainActor.run {
            let viewModel = WheelAppViewModel(visualFixture: .mixedPins)

            XCTAssertEqual(viewModel.wheelApplications.count, 8)
            XCTAssertEqual(viewModel.pinnedSlots.slots.map(\.position), [1, 5])
            XCTAssertEqual(viewModel.wheelSlots[1]?.stableIdentifier, "fixture:application.1")
            XCTAssertEqual(viewModel.wheelSlots[5]?.stableIdentifier, "fixture:application.5")
            XCTAssertEqual(viewModel.wheelSlots[5]?.runState, .terminated)
            XCTAssertEqual(Set(viewModel.wheelApplications.map(\.stableIdentifier)).count, 8)
            XCTAssertEqual(viewModel.hoveredApplicationIndex, 1)
        }
    }

    func testFixtureChangesDoNotPersistToAnotherLaunchOrInjectedUserStores() async {
        await MainActor.run {
            let userDefaults = WheelFixtureUserDefaults()
            let userSettings = WheelSettings(defaults: userDefaults)
            let userPins = WheelPinnedSlotStore(defaults: userDefaults)
            let savedPin = WheelVisualFixture.mixedPins.pins[0].application
            userSettings.setDirectionCount(4)
            userPins.pin(savedPin, at: 3)

            let fixture = WheelAppViewModel(visualFixture: .mixedPins)
            fixture.setDirectionCount(12)
            fixture.setVisibleItemCount(12)
            fixture.unpinApplication(at: 1)

            let fresh = WheelAppViewModel(visualFixture: .mixedPins)
            XCTAssertEqual(fresh.settings.directionCount, 8)
            XCTAssertEqual(fresh.pinnedSlots.slots.map(\.position), [1, 5])
            XCTAssertEqual(userSettings.directionCount, 4)
            XCTAssertEqual(userPins.slots.map(\.position), [3])
            XCTAssertEqual(userPins.application(at: 3), savedPin)
        }
    }

    func testLegacyFixturesUseEmptyIsolatedHistoryAndPins() async {
        await MainActor.run {
            for fixture in WheelAppFixture.allCases {
                let viewModel = WheelAppViewModel(fixture: fixture)
                XCTAssertTrue(viewModel.applicationHistory.isEmpty)
                XCTAssertTrue(viewModel.pinnedSlots.slots.isEmpty)
                XCTAssertEqual(viewModel.fixtureLabel, "Preview fixture")
            }
            for fixture in WheelGestureOverlayFixture.allCases {
                let viewModel = WheelAppViewModel(overlayFixture: fixture)
                XCTAssertTrue(viewModel.applicationHistory.isEmpty)
                XCTAssertTrue(viewModel.pinnedSlots.slots.isEmpty)
                XCTAssertEqual(viewModel.overlayState, fixture.state)
            }
        }
    }

    func testFixtureRuntimeNeverChecksPermissionStartsNativeInputOrCapturesApplications() async {
        await MainActor.run {
            for fixture in WheelVisualFixture.allCases {
                var permissionChecks = 0
                var permissionRequests = 0
                var inputFactories = 0
                let applicationMonitor = FixtureApplicationMonitorSpy()
                let activator = FixtureApplicationActivatorSpy()
                let viewModel = WheelAppViewModel(
                    permissionProvider: { permissionChecks += 1; return false },
                    permissionRequester: { permissionRequests += 1; return false },
                    monitorFactory: { _ in inputFactories += 1; return FixtureInputMonitorSpy() },
                    visualFixture: fixture,
                    applicationMonitor: applicationMonitor,
                    applicationActivator: activator
                )

                viewModel.start()
                viewModel.refreshPermission()
                viewModel.requestPermission()
                viewModel.setEnabled(false)
                viewModel.pause()
                viewModel.resume()
                viewModel.handleSystemSleep()
                viewModel.handleSystemWake()
                viewModel.shutdown()
                _ = viewModel.wheelSlots

                XCTAssertEqual(permissionChecks, 0)
                XCTAssertEqual(permissionRequests, 0)
                XCTAssertEqual(inputFactories, 0)
                XCTAssertEqual(applicationMonitor.startCalls, 0)
                XCTAssertEqual(applicationMonitor.stopCalls, 0)
                XCTAssertNil(applicationMonitor.onActivated)
                XCTAssertNil(applicationMonitor.onLaunched)
                XCTAssertNil(applicationMonitor.onTerminated)
                XCTAssertEqual(activator.activationCalls, 0)
                XCTAssertFalse(viewModel.isMonitoring)
                XCTAssertEqual(viewModel.status, .ready)
                XCTAssertFalse(viewModel.canPause)
                XCTAssertFalse(viewModel.canResume)
                XCTAssertFalse(viewModel.canRequestPermission)
            }
        }
    }

    func testNormalRuntimeWithInjectedEmptyStoresContainsNoSyntheticData() async {
        await MainActor.run {
            let defaults = WheelFixtureUserDefaults()
            let viewModel = WheelAppViewModel(
                permissionProvider: { false },
                settings: WheelSettings(defaults: defaults),
                applicationHistoryStore: WheelApplicationHistoryStore(persistence: WheelFixtureHistoryPersistence()),
                pinnedSlotStore: WheelPinnedSlotStore(defaults: defaults)
            )
            XCTAssertNil(viewModel.fixture)
            XCTAssertNil(viewModel.visualFixture)
            XCTAssertNil(viewModel.fixtureLabel)
            XCTAssertTrue(viewModel.applicationHistory.isEmpty)
            XCTAssertTrue(viewModel.wheelApplications.isEmpty)
            XCTAssertEqual(viewModel.status, .needsPermission)
        }
    }
}

@MainActor
private final class FixtureApplicationMonitorSpy: WheelApplicationMonitoring {
    var onActivated: ((WheelObservedApplication) -> Void)?
    var onLaunched: ((WheelObservedApplication) -> Void)?
    var onTerminated: ((WheelObservedApplication) -> Void)?
    private(set) var startCalls = 0
    private(set) var stopCalls = 0
    func start() { startCalls += 1 }
    func stop() { stopCalls += 1 }
}

@MainActor
private final class FixtureApplicationActivatorSpy: WheelApplicationActivating {
    private(set) var activationCalls = 0
    func activate(_ context: WheelApplicationContext, completion: @escaping (Result<Void, Error>) -> Void) {
        activationCalls += 1
        completion(.success(()))
    }
}

private final class FixtureInputMonitorSpy: InputEventMonitoring {
    var onEvent: ((GlobalInputEvent) -> Void)?
    var isRunning = false
    func start() throws { isRunning = true }
    func stop() { isRunning = false }
}
