import AppKit
import SwiftUI
import WheelMacOS

private final class DiagnosticsAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}

@main
struct WheelInputDiagnosticsApp: App {
    @NSApplicationDelegateAdaptor(DiagnosticsAppDelegate.self)
    private var appDelegate

    @StateObject private var viewModel = InputDiagnosticsViewModel()

    var body: some Scene {
        MenuBarExtra {
            InputDiagnosticsView(viewModel: viewModel, compact: true)
        } label: {
            Label(
                "Wheel Input Diagnostics — \(viewModel.session.status.rawValue)",
                systemImage: viewModel.session.status.symbolName
            )
            .labelStyle(.iconOnly)
            .accessibilityLabel(
                "Wheel Input Diagnostics: \(viewModel.session.status.rawValue)"
            )
        }
        .menuBarExtraStyle(.window)

        Window("Wheel Input Diagnostics", id: "diagnostics") {
            InputDiagnosticsView(viewModel: viewModel, compact: false)
        }
        .defaultSize(width: 560, height: 760)
    }
}
