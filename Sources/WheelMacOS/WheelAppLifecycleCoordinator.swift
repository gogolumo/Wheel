/// Owns the production app lifecycle boundary for Wheel's global input monitor.
///
/// SwiftUI can create and show the menu-bar and dashboard views independently.
/// Keeping lifecycle callbacks outside those views prevents opening another surface
/// from starting a second runtime or registering duplicate wake handlers.
@MainActor
public final class WheelAppLifecycleCoordinator {
    private let viewModel: WheelAppViewModel

    public private(set) var hasLaunched = false

    public init(viewModel: WheelAppViewModel) {
        self.viewModel = viewModel
    }

    public func launch() {
        guard !hasLaunched else { return }

        hasLaunched = true
        viewModel.start()
    }

    public func applicationDidBecomeActive() {
        guard hasLaunched else { return }

        viewModel.refreshPermission()
    }

    public func systemDidWake() {
        guard hasLaunched else { return }

        viewModel.handleSystemWake()
    }

    public func terminate() {
        guard hasLaunched else { return }

        hasLaunched = false
        viewModel.shutdown()
    }
}
