import AppKit
import SwiftUI
import WheelMacOS

@MainActor
private final class WheelAppDelegate: NSObject, NSApplicationDelegate {
    let viewModel: WheelAppViewModel

    private let lifecycleCoordinator: WheelAppLifecycleCoordinator
    private var overlayController: WheelGestureOverlayPanelController?

    override init() {
        let overlayFixture = WheelGestureOverlayFixture.requested(
            from: CommandLine.arguments
        )
        let viewModel = WheelAppViewModel(
            fixture: overlayFixture == nil
                ? WheelAppFixture.requested(from: CommandLine.arguments)
                : .ready,
            overlayFixture: overlayFixture
        )
        self.viewModel = viewModel
        lifecycleCoordinator = WheelAppLifecycleCoordinator(viewModel: viewModel)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        let overlayView = NSHostingView(
            rootView: WheelGestureOverlayView(viewModel: viewModel)
        )
        let overlayController = WheelGestureOverlayPanelController(
            viewModel: viewModel,
            contentView: overlayView
        )
        self.overlayController = overlayController
        overlayController.start()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidWake(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceWillSleep(_:)),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        lifecycleCoordinator.launch()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        lifecycleCoordinator.applicationDidBecomeActive()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        lifecycleCoordinator.terminate()
        overlayController?.shutdown()
        overlayController = nil
    }

    @objc
    private func workspaceDidWake(_ notification: Notification) {
        lifecycleCoordinator.systemDidWake()
    }

    @objc
    private func workspaceWillSleep(_ notification: Notification) {
        lifecycleCoordinator.systemWillSleep()
    }
}

@main
struct WheelApplication: App {
    @NSApplicationDelegateAdaptor(WheelAppDelegate.self)
    private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            WheelMenuBarView(viewModel: appDelegate.viewModel)
        } label: {
            WheelMenuBarLabel(viewModel: appDelegate.viewModel)
        }
        .menuBarExtraStyle(.window)

        Window("Wheel", id: "dashboard") {
            WheelDashboardView(viewModel: appDelegate.viewModel)
        }
        .defaultSize(width: 820, height: 580)
        .windowResizability(.contentMinSize)
    }
}
