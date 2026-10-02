import Foundation
import XCTest
@testable import WheelMacOS

/// Gesture and lifecycle tests explicitly start with empty local state. They
/// exercise production coordination while every workspace/persistence side
/// effect stays behind a test double, independent of the developer's Mac.
@MainActor
func makeIsolatedWheelAppViewModel(
    configuration: WheelAppConfiguration = .init(),
    permissionProvider: @escaping WheelAppViewModel.PermissionProvider,
    permissionRequester: @escaping WheelAppViewModel.PermissionRequester,
    monitorFactory: @escaping WheelAppViewModel.MonitorFactory,
    overlayDismissScheduler: WheelOverlayDismissScheduler = .mainQueue
) -> WheelAppViewModel {
    let defaults = WheelFixtureUserDefaults()
    return WheelAppViewModel(
        configuration: configuration,
        permissionProvider: permissionProvider,
        permissionRequester: permissionRequester,
        monitorFactory: monitorFactory,
        overlayDismissScheduler: overlayDismissScheduler,
        settings: WheelSettings(defaults: defaults),
        applicationMonitor: EmptyHistoryTestApplicationMonitor(),
        applicationActivator: EmptyHistoryTestApplicationActivator(),
        applicationHistoryStore: WheelApplicationHistoryStore(
            persistence: WheelFixtureHistoryPersistence()
        ),
        pinnedSlotStore: WheelPinnedSlotStore(defaults: defaults)
    )
}

@MainActor
private final class EmptyHistoryTestApplicationMonitor: WheelApplicationMonitoring {
    var onActivated: ((WheelObservedApplication) -> Void)?
    var onLaunched: ((WheelObservedApplication) -> Void)?
    var onTerminated: ((WheelObservedApplication) -> Void)?

    func start() {}
    func stop() {}
}

@MainActor
private final class EmptyHistoryTestApplicationActivator: WheelApplicationActivating {
    func activate(
        _ context: WheelApplicationContext,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        XCTFail("An empty-history test unexpectedly attempted application activation.")
        completion(.failure(WheelApplicationActivationError.missingLaunchTarget))
    }
}
