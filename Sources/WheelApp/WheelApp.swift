import AppKit
import SwiftUI
import WheelMacOS

private final class WheelAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}

@main
struct WheelApplication: App {
    @NSApplicationDelegateAdaptor(WheelAppDelegate.self)
    private var appDelegate

    @StateObject private var viewModel: WheelAppViewModel

    init() {
        _viewModel = StateObject(
            wrappedValue: WheelAppViewModel(fixture: Self.requestedFixture)
        )
    }

    var body: some Scene {
        MenuBarExtra {
            WheelMenuBarView(viewModel: viewModel)
        } label: {
            Label(
                "Wheel — \(viewModel.status.rawValue)",
                systemImage: viewModel.status.menuBarSymbolName
            )
            .labelStyle(.iconOnly)
            .accessibilityLabel("Wheel: \(viewModel.status.rawValue)")
        }
        .menuBarExtraStyle(.window)

        Window("Wheel", id: "dashboard") {
            WheelDashboardView(viewModel: viewModel)
        }
        .defaultSize(width: 820, height: 580)
        .windowResizability(.contentMinSize)
    }

    private static var requestedFixture: WheelAppFixture? {
        let arguments = CommandLine.arguments

        if let fixtureArgument = arguments.first(where: { $0.hasPrefix("--fixture=") }) {
            return WheelAppFixture(
                rawValue: String(fixtureArgument.dropFirst("--fixture=".count))
            )
        }

        guard let index = arguments.firstIndex(of: "--fixture") else {
            return nil
        }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }

        return WheelAppFixture(rawValue: arguments[valueIndex])
    }
}
