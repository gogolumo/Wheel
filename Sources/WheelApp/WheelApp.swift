import AppKit
import SwiftUI
import WheelMacOS

@MainActor
private final class WheelAppDelegate: NSObject, NSApplicationDelegate {
    let viewModel: WheelAppViewModel

    private let lifecycleCoordinator: WheelAppLifecycleCoordinator
    private var overlayController: WheelGestureOverlayPanelController?

    override init() {
        let visualFixture = WheelVisualFixture.requested(from: CommandLine.arguments)
        let overlayFixture = WheelGestureOverlayFixture.requested(
            from: CommandLine.arguments
        )
        let statusFixture: WheelAppFixture?
        if WheelFixtureRenderer.isRequested(CommandLine.arguments)
            || WheelBrandAudit.isRequested(CommandLine.arguments) || overlayFixture != nil {
            statusFixture = .ready
        } else {
            statusFixture = WheelAppFixture.requested(from: CommandLine.arguments)
        }
        let viewModel = WheelAppViewModel(
            fixture: statusFixture,
            overlayFixture: overlayFixture,
            visualFixture: visualFixture
        )
        self.viewModel = viewModel
        lifecycleCoordinator = WheelAppLifecycleCoordinator(viewModel: viewModel)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        if WheelBrandAudit.isRequested(CommandLine.arguments) {
            do {
                try WheelBrandAudit.verify()
            } catch {
                FileHandle.standardError.write(Data("Brand resource audit failed: \(error.localizedDescription)\n".utf8))
                exit(EXIT_FAILURE)
            }
            NSApplication.shared.terminate(nil)
            return
        }
        if WheelFixtureRenderer.isRequested(CommandLine.arguments) {
            do {
                try WheelFixtureRenderer.render(from: CommandLine.arguments)
            } catch {
                FileHandle.standardError.write(Data("Fixture export failed: \(error.localizedDescription)\n".utf8))
                exit(EXIT_FAILURE)
            }
            NSApplication.shared.terminate(nil)
            return
        }
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

        Window("Wheel Settings", id: "dashboard") {
            WheelDashboardView(viewModel: appDelegate.viewModel)
        }
        .defaultSize(width: 860, height: 640)
        .windowResizability(.contentMinSize)
    }
}
