import AppKit
import SwiftUI
import WheelDomain
import WheelMacOS

struct WheelMenuBarLabel: View {
    @ObservedObject var viewModel: WheelAppViewModel

    var body: some View {
        Label(
            "Wheel — \(displayedStatus)",
            systemImage: viewModel.isGestureActive
                ? "cursorarrow.motionlines"
                : viewModel.status.menuBarSymbolName
        )
        .labelStyle(.iconOnly)
        .accessibilityLabel("Wheel: \(displayedStatus)")
    }

    private var displayedStatus: String {
        viewModel.isGestureActive ? "Trigger Held" : viewModel.status.rawValue
    }
}

struct WheelMenuBarView: View {
    @ObservedObject var viewModel: WheelAppViewModel

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    primaryStateCard
                    if let notice = viewModel.notice {
                        NoticeView(message: notice)
                    }
                    BuildReadinessView(compact: true)
                }
                .padding(16)
            }

            Divider()
            footer
        }
        .frame(width: 390, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            WheelMark(size: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("Wheel")
                    .font(.headline)
                Text("Back and Forward for your Mac")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            StatusPill(
                status: viewModel.status,
                isGestureActive: viewModel.isGestureActive
            )
        }
        .padding(16)
    }

    @ViewBuilder
    private var primaryStateCard: some View {
        switch viewModel.status {
        case .needsPermission:
            PermissionCard(viewModel: viewModel)
        case .error:
            ErrorCard(viewModel: viewModel)
        case .disabled:
            DisabledCard(viewModel: viewModel)
        case .starting, .ready, .paused:
            GestureCard(viewModel: viewModel, compact: true)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                openWindow(id: "dashboard")
                NSApplication.shared.activate(ignoringOtherApps: true)
            } label: {
                Label("Open Wheel", systemImage: "rectangle.on.rectangle")
            }

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
    }
}

struct WheelDashboardView: View {
    enum Section: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case input = "Input"
        case wheel = "Wheel"
        case about = "About"

        var id: Self { self }

        var symbolName: String {
            switch self {
            case .overview: return "rectangle.grid.2x2"
            case .input: return "cursorarrow.motionlines"
            case .wheel: return "circle.hexagongrid"
            case .about: return "info.circle"
            }
        }
    }

    @ObservedObject var viewModel: WheelAppViewModel
    @State private var selection: Section? = .overview

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    WheelMark(size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Wheel")
                            .font(.headline)
                        Text("Early native MVP")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)

                List(Section.allCases, selection: $selection) { section in
                    Label(section.rawValue, systemImage: section.symbolName)
                        .tag(section)
                }
                .listStyle(.sidebar)

                VStack(alignment: .leading, spacing: 8) {
                    StatusPill(
                        status: viewModel.status,
                        isGestureActive: viewModel.isGestureActive
                    )
                    if viewModel.fixture != nil {
                        Label("Fixture preview", systemImage: "camera.viewfinder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 240)
        } detail: {
            Group {
                switch selection ?? .overview {
                case .overview:
                    OverviewView(viewModel: viewModel)
                case .input:
                    InputSettingsView(viewModel: viewModel)
                case .wheel:
                    WheelSettingsView(viewModel: viewModel)
                case .about:
                    AboutWheelView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 720, minHeight: 500)
    }
}

private struct OverviewView: View {
    @ObservedObject var viewModel: WheelAppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Global navigation, without the clutter")
                            .font(.largeTitle.weight(.semibold))
                        Text("Hold the trigger, move left or right, and release.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle(
                        "Wheel enabled",
                        isOn: Binding(
                            get: { viewModel.isEnabled },
                            set: viewModel.setEnabled
                        )
                    )
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(viewModel.fixture != nil)
                    .accessibilityLabel("Wheel enabled")
                }

                HStack(spacing: 12) {
                    MetricCard(
                        title: "Service",
                        value: viewModel.status.rawValue,
                        symbolName: viewModel.status.symbolName,
                        tint: viewModel.status.tint
                    )
                    MetricCard(
                        title: "Trigger",
                        value: viewModel.configuration.triggerType.productName,
                        symbolName: "option",
                        tint: .indigo
                    )
                    MetricCard(
                        title: "Recognized",
                        value: "\(viewModel.recognizedGestureCount)",
                        symbolName: "arrow.left.and.right",
                        tint: .blue
                    )
                }

                if viewModel.status == .needsPermission {
                    PermissionCard(viewModel: viewModel)
                } else if viewModel.status == .error {
                    ErrorCard(viewModel: viewModel)
                } else if viewModel.status == .disabled {
                    DisabledCard(viewModel: viewModel)
                } else {
                    GestureCard(viewModel: viewModel, compact: false)
                }

                if let notice = viewModel.notice {
                    NoticeView(message: notice)
                }

                BuildReadinessView(compact: false)
            }
            .padding(28)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }
}

private struct GestureCard: View {
    @ObservedObject var viewModel: WheelAppViewModel
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 14 : 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.isPaused ? "Input paused" : "Gesture input")
                        .font(.headline)
                    Text(instruction)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if viewModel.canPause {
                    Button("Pause", action: viewModel.pause)
                } else if viewModel.canResume {
                    Button("Resume", action: viewModel.resume)
                        .buttonStyle(.borderedProminent)
                }
            }

            HStack(spacing: compact ? 16 : 26) {
                DirectionGlyph(
                    direction: .left,
                    selected: viewModel.lastDirection == .left,
                    active: viewModel.isGestureActive
                )

                VStack(spacing: 6) {
                    Text(viewModel.configuration.triggerType.keycapLabel)
                        .font(.system(size: compact ? 16 : 19, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color(nsColor: .windowBackgroundColor))
                                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                        )
                    Text(viewModel.isGestureActive ? "Held" : "Trigger")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                DirectionGlyph(
                    direction: .right,
                    selected: viewModel.lastDirection == .right,
                    active: viewModel.isGestureActive
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 8 : 16)

            HStack(spacing: 12) {
                Label(
                    "\(viewModel.matchingTriggerSignalCount) matching signals",
                    systemImage: "waveform.path.ecg"
                )
                .monospacedDigit()

                Spacer()

                Text("Last edge \(formattedTriggerEdge)")
                    .monospaced()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "Matching trigger signals: \(viewModel.matchingTriggerSignalCount), "
                    + "last trigger edge: \(formattedTriggerEdge)"
            )

            HStack {
                Label(
                    viewModel.isGestureActive ? "Tracking movement" : statusLine,
                    systemImage: viewModel.isGestureActive
                        ? "waveform.path.ecg"
                        : "dot.radiowaves.left.and.right"
                )
                .font(.caption)
                .foregroundStyle(viewModel.isGestureActive ? .primary : .secondary)

                Spacer()

                if viewModel.eventTapRecoveryCount > 0 {
                    Text("Recovered \(viewModel.eventTapRecoveryCount)×")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(compact ? 16 : 20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.indigo.opacity(viewModel.isGestureActive ? 0.22 : 0.12),
                            Color.blue.opacity(viewModel.isGestureActive ? 0.15 : 0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.indigo.opacity(0.18))
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.isGestureActive)
    }

    private var instruction: String {
        if viewModel.isPaused {
            return "Resume when you want Wheel to observe the trigger again."
        }
        return "Hold \(viewModel.configuration.triggerType.productName), move, then release."
    }

    private var statusLine: String {
        guard let lastDirection = viewModel.lastDirection else {
            return "Waiting for a gesture"
        }
        if lastDirection == .none {
            return "Last movement was ignored"
        }
        return "Last gesture: \(lastDirection.rawValue.uppercased())"
    }

    private var formattedTriggerEdge: String {
        guard let isDown = viewModel.lastTriggerSignalIsDown else {
            return "—"
        }
        return isDown ? "DOWN" : "UP"
    }
}

private struct DirectionGlyph: View {
    let direction: Direction
    let selected: Bool
    let active: Bool

    var body: some View {
        Image(systemName: direction == .left ? "arrow.left" : "arrow.right")
            .font(.system(size: 28, weight: .semibold, design: .rounded))
            .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            .frame(width: 54, height: 54)
            .background(
                Circle()
                    .fill(selected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04))
            )
            .scaleEffect(active ? 1.05 : 1)
            .accessibilityLabel(direction == .left ? "Previous" : "Next")
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct PermissionCard: View {
    @ObservedObject var viewModel: WheelAppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Input Monitoring is required", systemImage: "hand.raised.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text(
                "Wheel needs permission to observe the chosen trigger and pointer movement "
                    + "outside its own window. The monitor is listen-only and never blocks input."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            HStack {
                Button("Request Access", action: viewModel.requestPermission)
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canRequestPermission)

                Button("Open Privacy Settings", action: SystemSettings.openInputMonitoring)

                Spacer()

                Button("Check Again", action: viewModel.refreshPermission)
                    .disabled(viewModel.fixture != nil)
            }
        }
        .cardStyle(tint: .orange)
    }
}

private struct ErrorCard: View {
    @ObservedObject var viewModel: WheelAppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Wheel could not start", systemImage: "xmark.octagon.fill")
                .font(.headline)
                .foregroundStyle(.red)

            Text(viewModel.errorMessage ?? "An unknown input-monitoring error occurred.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Button("Try Again", action: viewModel.refreshPermission)
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.fixture != nil)
                Button("Open Privacy Settings", action: SystemSettings.openInputMonitoring)
            }
        }
        .cardStyle(tint: .red)
    }
}

private struct DisabledCard: View {
    @ObservedObject var viewModel: WheelAppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Wheel is off", systemImage: "power")
                .font(.headline)
            Text("No global input is being observed while Wheel is disabled.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Enable Wheel") {
                viewModel.setEnabled(true)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.fixture != nil)
        }
        .cardStyle(tint: .secondary)
    }
}

private struct NoticeView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "info.circle")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
            )
            .accessibilityLabel(message)
    }
}

private struct BuildReadinessView: View {
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MVP readiness")
                    .font(.headline)
                Spacer()
                Text("1 of 3 connected")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ReadinessRow(
                title: "Gesture input",
                detail: "Live and listen-only",
                symbolName: "checkmark.circle.fill",
                tint: .green
            )
            ReadinessRow(
                title: "Context history",
                detail: "Domain ready; native capture pending",
                symbolName: "circle.dashed",
                tint: .secondary
            )
            ReadinessRow(
                title: "Context restoration",
                detail: "Not connected in this build",
                symbolName: "circle.dashed",
                tint: .secondary
            )

            if !compact {
                Text(
                    "The interface never reports navigation success until a real capture and "
                        + "restoration result is available."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }
        }
        .cardStyle(tint: .indigo)
    }
}

private struct ReadinessRow: View {
    let title: String
    let detail: String
    let symbolName: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .foregroundStyle(tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let symbolName: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.headline)
                .lineLimit(1)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07))
        }
    }
}

private struct WheelSettingsView: View {
    @ObservedObject var viewModel: WheelAppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Wheel")
                        .font(.largeTitle.weight(.semibold))
                    Text("Control how many application targets Wheel presents and how they are arranged.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                GroupBox("Radial layout") {
                    VStack(alignment: .leading, spacing: 16) {
                        LabeledContent("Visible apps") {
                            Stepper(
                                value: Binding(
                                    get: { viewModel.settings.visibleItemCount },
                                    set: viewModel.setVisibleItemCount
                                ),
                                in: WheelSettings.visibleItemRange
                            ) {
                                Text("\(viewModel.settings.visibleItemCount)")
                                    .monospacedDigit()
                            }
                            .frame(width: 120)
                        }

                        LabeledContent("Directions") {
                            Picker(
                                "Directions",
                                selection: Binding(
                                    get: { viewModel.settings.directionCount },
                                    set: viewModel.setDirectionCount
                                )
                            ) {
                                ForEach(WheelSettings.supportedDirectionCounts, id: \.self) { count in
                                    Text("\(count)").tag(count)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                        }

                        Text(
                            "Application count and direction count are stored separately. "
                                + "The current single-ring overlay can display up to the smaller "
                                + "of the two values."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                GroupBox("History") {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle(
                            "Remember closed applications",
                            isOn: Binding(
                                get: { viewModel.settings.rememberClosedApplications },
                                set: viewModel.setRememberClosedApplications
                            )
                        )

                        LabeledContent("History capacity") {
                            Stepper(
                                value: Binding(
                                    get: { viewModel.settings.historyCapacity },
                                    set: viewModel.setHistoryCapacity
                                ),
                                in: WheelSettings.historyCapacityRange,
                                step: 10
                            ) {
                                Text("\(viewModel.settings.historyCapacity)")
                                    .monospacedDigit()
                            }
                            .frame(width: 120)
                        }

                        HStack {
                            Label(
                                "\(viewModel.applicationHistory.count) captured transitions",
                                systemImage: "clock.arrow.circlepath"
                            )
                            Spacer()
                            Text(
                                "\(viewModel.wheelApplications.count) available now"
                            )
                            .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 6)
                }

                GroupBox("Selection") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(
                            "Hold the configured trigger, move toward an application icon, "
                                + "and release. Running apps are activated; terminated apps are relaunched."
                        )
                        .font(.callout)

                        Label(
                            "Exact window, tab, folder, and editor restoration are not claimed by this build.",
                            systemImage: "info.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(28)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }
}

private struct InputSettingsView: View {
    @ObservedObject var viewModel: WheelAppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Input")
                        .font(.largeTitle.weight(.semibold))
                    Text("Choose a trigger and calibrate horizontal movement.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                GroupBox("Trigger") {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Trigger key", selection: triggerBinding) {
                            Text("Right Option").tag(TriggerType.rightOption)
                            Text("Caps Lock — Experimental").tag(TriggerType.capsLock)
                        }
                        .pickerStyle(.radioGroup)

                        if viewModel.configuration.triggerType == .capsLock {
                            Label(
                                "Caps Lock changes the system alpha-shift state and remains experimental.",
                                systemImage: "exclamationmark.triangle"
                            )
                            .font(.caption)
                            .foregroundStyle(.orange)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                }

                GroupBox("Gesture calibration") {
                    VStack(alignment: .leading, spacing: 18) {
                        LabeledContent("Minimum distance") {
                            Text("\(Int(viewModel.configuration.minimumHorizontalDistance)) pt")
                                .monospacedDigit()
                        }
                        Slider(value: distanceBinding, in: 40...240, step: 10)

                        LabeledContent("Horizontal dominance") {
                            Text(
                                String(
                                    format: "%.1fx",
                                    viewModel.configuration.minimumDominanceRatio
                                )
                            )
                            .monospacedDigit()
                        }
                        Slider(value: dominanceBinding, in: 1...3, step: 0.1)

                        Text(
                            "A movement must reach the distance threshold and be more horizontal "
                                + "than vertical. Changes restart the listen-only monitor."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                GroupBox("Permission") {
                    HStack {
                        Label(
                            viewModel.permissionGranted ? "Granted" : "Required",
                            systemImage: viewModel.permissionGranted
                                ? "checkmark.shield.fill"
                                : "exclamationmark.shield.fill"
                        )
                        .foregroundStyle(viewModel.permissionGranted ? .green : .orange)

                        Spacer()

                        Button("Check Again", action: viewModel.refreshPermission)
                        Button("Open System Settings", action: SystemSettings.openInputMonitoring)
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(28)
            .disabled(viewModel.fixture != nil)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }

    private var triggerBinding: Binding<TriggerType> {
        Binding(
            get: { viewModel.configuration.triggerType },
            set: { trigger in
                var configuration = viewModel.configuration
                configuration.triggerType = trigger
                viewModel.updateConfiguration(configuration)
            }
        )
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

private struct AboutWheelView: View {
    var body: some View {
        VStack(spacing: 18) {
            WheelMark(size: 74)
            Text("Wheel")
                .font(.largeTitle.weight(.semibold))
            Text("Back and Forward for your whole Mac.")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Native prototype · macOS 14+")
                .font(.callout.monospaced())
                .foregroundStyle(.tertiary)
            Text(
                "This build validates the menu-bar lifecycle, permission recovery, and "
                    + "gesture feedback. Context capture and restoration are intentionally "
                    + "reported as unavailable until their feasibility gates pass."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 480)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }
}

private struct StatusPill: View {
    let status: WheelAppStatus
    let isGestureActive: Bool

    var body: some View {
        Label(displayedStatus, systemImage: displayedSymbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(displayedTint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(displayedTint.opacity(0.12)))
            .accessibilityLabel("Wheel status: \(displayedStatus)")
    }

    private var displayedStatus: String {
        isGestureActive ? "Trigger Held" : status.rawValue
    }

    private var displayedSymbolName: String {
        isGestureActive ? "cursorarrow.motionlines" : status.symbolName
    }

    private var displayedTint: Color {
        isGestureActive ? .indigo : status.tint
    }
}

private struct WheelMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.indigo, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private enum SystemSettings {
    static func openInputMonitoring() {
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

private extension View {
    func cardStyle(tint: Color) -> some View {
        padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.07))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(tint.opacity(0.16))
            }
    }
}

extension WheelAppStatus {
    var symbolName: String {
        switch self {
        case .starting: return "hourglass"
        case .disabled: return "power"
        case .needsPermission: return "exclamationmark.shield"
        case .ready: return "checkmark.circle.fill"
        case .paused: return "pause.circle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    var menuBarSymbolName: String {
        switch self {
        case .ready: return "arrow.left.arrow.right.circle.fill"
        case .starting: return "arrow.left.arrow.right.circle"
        case .disabled: return "circle.slash"
        case .needsPermission: return "exclamationmark.triangle"
        case .paused: return "pause.circle"
        case .error: return "xmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .starting: return .secondary
        case .disabled: return .secondary
        case .needsPermission: return .orange
        case .ready: return .green
        case .paused: return .yellow
        case .error: return .red
        }
    }
}

private extension TriggerType {
    var productName: String {
        switch self {
        case .rightOption: return "Right Option"
        case .capsLock: return "Caps Lock"
        case .mouseSideButton: return "Mouse Side Button"
        }
    }

    var keycapLabel: String {
        switch self {
        case .rightOption: return "Right ⌥"
        case .capsLock: return "⇪ Caps Lock"
        case .mouseSideButton: return "Mouse 4"
        }
    }
}
