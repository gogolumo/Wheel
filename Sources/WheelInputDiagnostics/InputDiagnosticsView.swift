import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers
import WheelDomain
import WheelMacOS

struct InputDiagnosticsView: View {
    @ObservedObject var viewModel: InputDiagnosticsViewModel
    let compact: Bool

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                statusSection
                permissionSection
                configurationSection
                resultsSection
                actionsSection
            }
            .padding(16)
        }
        .frame(
            minWidth: compact ? 440 : 500,
            idealWidth: compact ? 440 : 540,
            minHeight: compact ? 620 : 680
        )
        .onAppear {
            viewModel.refreshPermission()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            viewModel.refreshPermission()
        }
        .onReceive(
            NSWorkspace.shared.notificationCenter.publisher(
                for: NSWorkspace.didWakeNotification
            )
        ) { _ in
            viewModel.handleSystemWake()
        }
    }

    private var statusSection: some View {
        GroupBox("Status") {
            VStack(alignment: .leading, spacing: 8) {
                Label(
                    viewModel.session.status.rawValue,
                    systemImage: viewModel.session.status.symbolName
                )
                .font(.title2.weight(.semibold))
                .accessibilityLabel(
                    "Diagnostics status: \(viewModel.session.status.rawValue)"
                )

                Text(viewModel.session.status.explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if let notice = viewModel.session.notice {
                    Label(notice, systemImage: "info.circle")
                        .font(.callout)
                }

                if let error = viewModel.session.errorMessage {
                    Label(error, systemImage: "xmark.octagon")
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                HStack {
                    Label(
                        viewModel.session.triggerIsHeld
                            ? "Trigger is held"
                            : "Trigger is released",
                        systemImage: viewModel.session.triggerIsHeld
                            ? "hand.point.up.left.fill"
                            : "hand.point.up.left"
                    )

                    Spacer()

                    Label(
                        viewModel.session.evidenceSaved
                            ? "JSON saved"
                            : "JSON not saved",
                        systemImage: viewModel.session.evidenceSaved
                            ? "doc.badge.checkmark"
                            : "doc"
                    )
                }
                .font(.callout)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private var permissionSection: some View {
        GroupBox("Input Monitoring") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(
                        viewModel.session.permissionGranted ? "Granted" : "Missing",
                        systemImage: viewModel.session.permissionGranted
                            ? "checkmark.shield"
                            : "exclamationmark.shield"
                    )
                    .font(.headline)

                    Spacer()

                    Button("Check Again") {
                        viewModel.refreshPermission()
                    }
                }

                if !viewModel.session.permissionGranted {
                    Text(
                        "Wheel cannot listen until the host app has Input Monitoring access. "
                            + "Permission is requested only when you press the button."
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)

                    HStack {
                        Button("Request Access") {
                            viewModel.requestPermission()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Open Privacy Settings") {
                            openPrivacySettings()
                        }
                    }
                } else {
                    Button("Open Privacy Settings") {
                        openPrivacySettings()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private var configurationSection: some View {
        GroupBox("Test Configuration") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Privacy-safe run label", text: $viewModel.configuration.runLabel)
                    .textFieldStyle(.roundedBorder)

                Text(
                    "Do not include account names, document titles, URLs, paths, or device IDs."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Picker("Trigger", selection: $viewModel.configuration.triggerType) {
                    ForEach(TriggerType.allCases, id: \.self) { trigger in
                        Text(trigger.diagnosticsName).tag(trigger)
                    }
                }

                Stepper(
                    value: $viewModel.configuration.targetSequenceCount,
                    in: 1...10_000
                ) {
                    Text("Target sequences: \(viewModel.configuration.targetSequenceCount)")
                }

                Stepper(
                    value: $viewModel.configuration.minimumHorizontalDistance,
                    in: 1...5_000,
                    step: 10
                ) {
                    Text(
                        "Minimum horizontal distance: "
                            + String(
                                format: "%.0f pt",
                                viewModel.configuration.minimumHorizontalDistance
                            )
                    )
                }

                Stepper(
                    value: $viewModel.configuration.minimumDominanceRatio,
                    in: 1...100,
                    step: 0.1
                ) {
                    Text(
                        "Horizontal dominance: "
                            + String(
                                format: "%.1fx",
                                viewModel.configuration.minimumDominanceRatio
                            )
                    )
                }

                if viewModel.configuration.triggerType == .mouseSideButton {
                    Stepper(
                        value: $viewModel.configuration.mouseButtonNumber,
                        in: 3...31
                    ) {
                        Text(
                            "Mouse side-button number: "
                                + "\(viewModel.configuration.mouseButtonNumber)"
                        )
                    }
                }

                if let validationError = viewModel.configuration.validationError {
                    Label(validationError, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }
            .disabled(viewModel.configurationLocked)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private var resultsSection: some View {
        let statistics = viewModel.session.statistics
        let target = viewModel.configurationLocked
            ? viewModel.session.configuration.targetSequenceCount
            : viewModel.configuration.targetSequenceCount

        return GroupBox("Live Results") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Progress")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(statistics.completedSequenceCount) / \(target)")
                            .font(.title2.monospacedDigit().weight(.semibold))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Last direction")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Label(
                            viewModel.session.lastDirection?.rawValue.uppercased() ?? "—",
                            systemImage: viewModel.session.lastDirection?.symbolName
                                ?? "minus"
                        )
                        .font(.title2.monospaced().weight(.bold))
                        .accessibilityLabel(
                            "Last recognized direction: "
                                + (viewModel.session.lastDirection?.rawValue ?? "none yet")
                        )
                    }
                }

                ProgressView(
                    value: Double(min(statistics.completedSequenceCount, target)),
                    total: Double(target)
                )

                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 7) {
                    metricRow("LEFT", value: statistics.leftCount)
                    metricRow("RIGHT", value: statistics.rightCount)
                    metricRow("NONE", value: statistics.noneCount)
                    metricRow("Pointer events", value: statistics.pointerMovementCount)
                    metricRow("Callback samples", value: statistics.callbackSampleCount)
                    metricRow(
                        "Matching trigger signals",
                        value: viewModel.session.matchingTriggerSignalCount
                    )

                    GridRow {
                        Text("Last trigger edge")
                            .foregroundStyle(.secondary)
                        Text(formattedTriggerEdge)
                            .monospaced()
                            .accessibilityLabel(
                                "Last matching trigger edge: \(formattedTriggerEdge)"
                            )
                    }

                    GridRow {
                        Text("Median callback latency")
                            .foregroundStyle(.secondary)
                        Text(formattedLatency)
                            .monospacedDigit()
                    }

                    metricRow(
                        "Event-tap recoveries",
                        value: statistics.eventTapRecoveryCount
                    )
                }
                .font(.callout)

                Text(
                    "Aggregate evidence cannot detect missed physical attempts, native side "
                        + "effects, or broad hardware compatibility. Manual review is still required."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private var actionsSection: some View {
        GroupBox("Actions") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button("Start Listening") {
                        viewModel.startListening()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canStart)

                    Button("Stop & Save Partial Evidence") {
                        stopAndSavePartialEvidence()
                    }
                    .disabled(!viewModel.canStop)
                }

                HStack {
                    Button("Reset") {
                        viewModel.reset()
                    }
                    .disabled(!viewModel.canReset)

                    Button("Export JSON") {
                        exportEvidence()
                    }
                    .disabled(!viewModel.canExport)

                    Spacer()

                    if compact {
                        Button("Open Window") {
                            openWindow(id: "diagnostics")
                            NSApplication.shared.activate(ignoringOtherApps: true)
                        }
                    }
                }

                Divider()

                Button("Quit Wheel Diagnostics") {
                    viewModel.shutdown()
                    NSApplication.shared.terminate(nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func metricRow(_ name: String, value: Int) -> some View {
        GridRow {
            Text(name)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .monospacedDigit()
        }
    }

    private var formattedLatency: String {
        guard let latency = viewModel.session.statistics.medianCallbackLatencyMilliseconds else {
            return "n/a"
        }
        return String(format: "%.2f ms", latency)
    }

    private var formattedTriggerEdge: String {
        guard let isDown = viewModel.session.lastTriggerSignalIsDown else {
            return "—"
        }
        return isDown ? "DOWN" : "UP"
    }

    private func stopAndSavePartialEvidence() {
        do {
            let data = try viewModel.stopAndPreparePartialEvidence()
            presentSavePanel(for: data)
        } catch {
            viewModel.reportExportError(error)
        }
    }

    private func exportEvidence() {
        do {
            presentSavePanel(for: try viewModel.exportEvidenceData())
        } catch {
            viewModel.reportExportError(error)
        }
    }

    private func presentSavePanel(for data: Data) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = viewModel.suggestedEvidenceFilename
        panel.title = "Export Wheel Input Evidence"
        panel.message = "The JSON contains aggregate counters and test configuration only."

        NSApplication.shared.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let destination = panel.url else {
            return
        }

        do {
            try data.write(to: destination, options: .atomic)
            viewModel.markEvidenceSaved()
        } catch {
            viewModel.reportExportError(error)
        }
    }

    private func openPrivacySettings() {
        if let privacyURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        ), NSWorkspace.shared.open(privacyURL) {
            return
        }

        NSWorkspace.shared.open(
            URL(fileURLWithPath: "/System/Applications/System Settings.app")
        )
    }
}

private extension TriggerType {
    var diagnosticsName: String {
        switch self {
        case .rightOption:
            return "Right Option"
        case .capsLock:
            return "Caps Lock — Experimental"
        case .mouseSideButton:
            return "Mouse Side Button"
        }
    }
}

private extension Direction {
    var symbolName: String {
        switch self {
        case .left:
            return "arrow.left"
        case .right:
            return "arrow.right"
        case .none:
            return "minus"
        }
    }
}

extension InputDiagnosticsStatus {
    var symbolName: String {
        switch self {
        case .permissionRequired:
            return "exclamationmark.triangle"
        case .ready:
            return "checkmark.circle"
        case .listening:
            return "wave.3.right"
        case .triggerHeld:
            return "hand.point.up.left.fill"
        case .completed:
            return "checkmark.seal"
        case .stopped:
            return "stop.circle"
        case .eventTapRecovered:
            return "arrow.clockwise.circle"
        case .error:
            return "xmark.octagon"
        }
    }

    var explanation: String {
        switch self {
        case .permissionRequired:
            return "Grant Input Monitoring before starting a diagnostic run."
        case .ready:
            return "Configuration is valid and Wheel is ready to listen."
        case .listening:
            return "Wheel is observing input in listen-only mode."
        case .triggerHeld:
            return "The selected trigger is currently held."
        case .completed:
            return "The observed-sequence target was reached. Export the JSON evidence."
        case .stopped:
            return "Monitoring is stopped; partial aggregate evidence is available."
        case .eventTapRecovered:
            return "The event tap was re-enabled and transient trigger state was cleared."
        case .error:
            return "Diagnostics encountered an error. Review the message below."
        }
    }
}
