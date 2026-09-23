import AppKit
import SwiftUI
import WheelMacOS

@MainActor
private final class WheelAppDelegate: NSObject, NSApplicationDelegate {
    let viewModel: WheelAppViewModel

    private let lifecycleCoordinator: WheelAppLifecycleCoordinator

    override init() {
        let viewModel = WheelAppViewModel(
            fixture: WheelAppFixture.requested(from: CommandLine.arguments)
        )
        self.viewModel = viewModel
        lifecycleCoordinator = WheelAppLifecycleCoordinator(viewModel: viewModel)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidWake(_:)),
            name: NSWorkspace.didWakeNotification,
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
        lifecycleCoordinator.terminate()
    }

    @objc
    private func workspaceDidWake(_ notification: Notification) {
        lifecycleCoordinator.systemDidWake()
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
