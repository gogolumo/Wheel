import SwiftUI
import WheelMacOS

struct WheelAdvancedSettingsView: View {
    @ObservedObject var viewModel: WheelAppViewModel

    var body: some View {
        WheelSettingsPage(
            title: "Advanced",
            subtitle: "Calibration, runtime diagnostics, and current capabilities."
        ) {
            Section("Input diagnostics") {
                LabeledContent("Recognized gestures", value: "\(viewModel.recognizedGestureCount)")
                LabeledContent("Matching trigger signals", value: "\(viewModel.matchingTriggerSignalCount)")
                LabeledContent("Last trigger edge", value: triggerEdge)
                LabeledContent("Event-tap recoveries", value: "\(viewModel.eventTapRecoveryCount)")
                LabeledContent("Gesture session", value: viewModel.isGestureActive ? "Active" : "Idle")
                LabeledContent("Last direction", value: viewModel.lastDirection?.rawValue.uppercased() ?? "—")
                LabeledContent("Last application target", value: viewModel.lastApplicationAction ?? "—")
            }
            .monospacedDigit()

            Section("Gesture calibration") {
                LabeledContent("Minimum distance", value: "\(Int(viewModel.configuration.minimumHorizontalDistance)) pt")
                Slider(value: distanceBinding, in: 40...240, step: 10)
                    .accessibilityLabel("Minimum gesture distance")
                    .disabled(viewModel.fixture != nil)
                LabeledContent(
                    "Horizontal dominance",
                    value: String(format: "%.1f×", viewModel.configuration.minimumDominanceRatio)
                )
                Slider(value: dominanceBinding, in: 1...3, step: 0.1)
                    .accessibilityLabel("Horizontal gesture dominance")
                    .disabled(viewModel.fixture != nil)
                Text(
                    "Minimum distance controls when a sector can be selected. Horizontal dominance "
                        + "controls horizontal gesture feedback. Changes restart the listen-only monitor."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Current capabilities") {
                LabeledContent("Global input", value: inputCapability)
                LabeledContent("Application capture", value: "Application identity only")
                LabeledContent("Application restoration", value: "Switch or reopen")
                LabeledContent("Window / tab / document restoration", value: "Not implemented")
                LabeledContent("Local history", value: "\(viewModel.applicationHistory.count) transitions")
                LabeledContent("Populated sectors", value: "\(viewModel.wheelApplications.count)")
                Text(
                    "Only real activation or relaunch results are reported by the runtime. "
                        + "Physical input, focus, full-screen, and display behavior still require macOS validation."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let notice = viewModel.notice {
                Section("Latest runtime message") {
                    Text(notice)
                        .font(.callout)
                        .textSelection(.enabled)
                }
            }

            if let fixtureLabel = viewModel.fixtureLabel {
                Section("Fixture preview") {
                    Label(fixtureLabel, systemImage: "camera.viewfinder")
                    Text("Synthetic review data. Global input, permission requests, and settings changes are disabled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var inputCapability: String {
        if viewModel.fixture != nil { return "Simulated preview" }
        return viewModel.isMonitoring ? "Listen-only · connected" : "Stopped"
    }

    private var triggerEdge: String {
        guard let isDown = viewModel.lastTriggerSignalIsDown else { return "—" }
        return isDown ? "DOWN" : "UP"
    }

    private var distanceBinding: Binding<Double> {
        Binding(
            get: { viewModel.configuration.minimumHorizontalDistance },
            set: { distance in
                var configuration = viewModel.configuration
                configuration.minimumHorizontalDistance = distance
                viewModel.updateConfiguration(configuration)
            }
        )
    }

    private var dominanceBinding: Binding<Double> {
        Binding(
            get: { viewModel.configuration.minimumDominanceRatio },
            set: { ratio in
                var configuration = viewModel.configuration
                configuration.minimumDominanceRatio = ratio
                viewModel.updateConfiguration(configuration)
            }
        )
    }
}
