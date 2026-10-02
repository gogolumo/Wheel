import AppKit
import SwiftUI
import WheelDomain
import WheelMacOS

struct WheelGeneralSettingsView: View {
    @ObservedObject var viewModel: WheelAppViewModel

    var body: some View {
        WheelSettingsPage(
            title: "General",
            subtitle: "Your applications, right where you need them."
        ) {
            Section("Wheel") {
                Toggle(
                    "Enable Wheel",
                    isOn: Binding(get: { viewModel.isEnabled }, set: viewModel.setEnabled)
                )
                .disabled(viewModel.fixture != nil)

                LabeledContent("Status") {
                    WheelStatusLabel(
                        status: viewModel.status,
                        isGestureActive: viewModel.isGestureActive
                    )
                }

                Text(runtimeDescription)
                    .foregroundStyle(.secondary)
                    .font(.callout)

                if viewModel.status == .ready || viewModel.isPaused {
                    Button(
                        viewModel.isPaused ? "Resume Wheel" : "Pause Wheel",
                        action: viewModel.isPaused ? viewModel.resume : viewModel.pause
                    )
                    .disabled(viewModel.isPaused ? !viewModel.canResume : !viewModel.canPause)
                }
            }

            Section("Trigger") {
                Picker("Trigger key", selection: triggerBinding) {
                    Text("Right Option").tag(TriggerType.rightOption)
                    Text("Caps Lock — Experimental").tag(TriggerType.capsLock)
                }
                .disabled(viewModel.fixture != nil)

                Text(
                    "Hold \(viewModel.configuration.triggerType.productName), "
                        + "move toward an application, then release to switch or reopen it."
                )
                .font(.callout)
                .foregroundStyle(.secondary)

                if viewModel.configuration.triggerType == .capsLock {
                    Label(
                        "Caps Lock also changes the system caps lock state.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }

            if !viewModel.permissionGranted {
                Section("Input Monitoring") {
                    Label("Permission is needed for global gestures.", systemImage: "hand.raised")
                    Button("Request Access", action: viewModel.requestPermission)
                        .disabled(!viewModel.canRequestPermission)
                    Button("Open Privacy Settings", action: WheelSystemSettings.openInputMonitoring)
                        .disabled(viewModel.fixture != nil)
                }
            }

            if viewModel.status == .error {
                Section("Attention needed") {
                    Label(
                        viewModel.errorMessage ?? "Wheel could not start input monitoring.",
                        systemImage: "exclamationmark.octagon"
                    )
                    Button("Try Again", action: viewModel.refreshPermission)
                        .disabled(viewModel.fixture != nil)
                }
            }

            Section("At launch") {
                Text("Wheel starts when you open the application and lives in your menu bar.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var runtimeDescription: String {
        switch viewModel.status {
        case .starting: return "Wheel is preparing global input."
        case .disabled: return "Wheel is off. Global input and application capture are stopped."
        case .needsPermission: return "Application history can update while global gestures await permission."
        case .ready: return "Ready for the next gesture. Input is observed without blocking other apps."
        case .paused: return "Global input is paused. Application history continues to update."
        case .error: return "Input monitoring needs attention. Review the message below."
        }
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
}

struct WheelLayoutSettingsView: View {
    @ObservedObject var viewModel: WheelAppViewModel

    var body: some View {
        let slots = viewModel.wheelSlots

        WheelSettingsPage(
            title: "Wheel Layout",
            subtitle: "A familiar place for every application."
        ) {
            Section("Radial layout") {
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
                .disabled(viewModel.fixture != nil)

                Stepper(
                    value: Binding(
                        get: { viewModel.settings.visibleItemCount },
                        set: viewModel.setVisibleItemCount
                    ),
                    in: WheelSettings.visibleItemRange
                ) {
                    LabeledContent("Visible applications", value: "\(viewModel.settings.visibleItemCount)")
                        .monospacedDigit()
                }
                .disabled(viewModel.fixture != nil)

                Text(
                    "Directions set the sector positions. Visible applications limits recent "
                        + "history targets; pinned sectors always keep their assignments."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            Section("Preview") {
                VStack(spacing: WheelVisualTokens.Spacing.medium) {
                    WheelRingView(
                        slots: slots,
                        pinnedIndices: Set(slots.indices.filter(viewModel.isPinnedSlot)),
                        selectedIndex: nil,
                        isResult: false,
                        centerText: "Move to select",
                        triggerHint: viewModel.configuration.triggerType.keycapLabel
                    )
                    .frame(width: 492, height: 492)
                    .scaleEffect(0.55)
                    .frame(width: 280, height: 280)
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "Wheel preview: \(viewModel.settings.directionCount) directions, "
                            + "\(slots.compactMap { $0 }.count) applications."
                    )

                    Text(
                        viewModel.fixture == nil
                            ? "Uses your current applications and pins. This preview does not start a gesture."
                            : "Synthetic fixture applications. Global gestures and settings changes are disabled."
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

struct WheelHistorySettingsView: View {
    @ObservedObject var viewModel: WheelAppViewModel

    var body: some View {
        WheelSettingsPage(
            title: "History",
            subtitle: "Keep useful destinations close, with bounded local history."
        ) {
            Section("Applications") {
                Toggle(
                    "Remember closed applications",
                    isOn: Binding(
                        get: { viewModel.settings.rememberClosedApplications },
                        set: viewModel.setRememberClosedApplications
                    )
                )
                .disabled(viewModel.fixture != nil)

                Text(
                    "Recently closed applications remain in the Wheel with a reopen marker. "
                        + "Selecting one uses its installed application to launch it again."
                )
                .font(.callout)
                .foregroundStyle(.secondary)

                Stepper(
                    value: Binding(
                        get: { viewModel.settings.historyCapacity },
                        set: viewModel.setHistoryCapacity
                    ),
                    in: WheelSettings.historyCapacityRange,
                    step: 10
                ) {
                    LabeledContent("History capacity", value: "\(viewModel.settings.historyCapacity) transitions")
                        .monospacedDigit()
                }
                .disabled(viewModel.fixture != nil)

                Text("Reducing capacity removes the oldest entries beyond that limit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Label("History stays on this Mac.", systemImage: "lock")
                Text(
                    "Wheel stores application identity, display name, timestamps, and run state. "
                        + "It does not capture document contents, browser pages, screenshots, or typed text."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
    }
}

struct WheelAppearanceSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        WheelSettingsPage(
            title: "Appearance",
            subtitle: "Glass and contrast adapt to your Mac."
        ) {
            Section("System appearance") {
                LabeledContent("Appearance", value: colorScheme == .dark ? "Dark · System" : "Light · System")
                Text("Wheel follows macOS appearance and uses native materials for its floating surfaces.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Accessibility") {
                LabeledContent("Reduce Motion", value: reduceMotion ? "On" : "Off")
                LabeledContent("Reduce Transparency", value: reduceTransparency ? "On" : "Off")
                LabeledContent("Increase Contrast", value: colorSchemeContrast == .increased ? "On" : "Off")
                LabeledContent("Differentiate Without Color", value: differentiateWithoutColor ? "On" : "Off")
                Text("These settings are managed in System Settings → Accessibility → Display.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct WheelAboutSettingsView: View {
    var body: some View {
        WheelSettingsPage(
            title: "About Wheel",
            subtitle: "Back and Forward for your whole Mac."
        ) {
            Section {
                HStack(spacing: WheelVisualTokens.Spacing.large) {
                    WheelMark(size: 54)
                    VStack(alignment: .leading, spacing: WheelVisualTokens.Spacing.small) {
                        Text("Wheel")
                            .font(.title2.weight(.semibold))
                        Text("Native macOS utility · macOS 14+")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, WheelVisualTokens.Spacing.medium)
                LabeledContent("Version", value: version)
                Text(
                    "This build captures applications locally and switches or reopens them. "
                        + "Exact window, tab, folder, and editor restoration remain future capabilities."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            Section("Project") {
                Link("Wheel on GitHub", destination: URL(string: "https://github.com/gogolumo/Wheel")!)
                Text("Local-first. No account or cloud service is required.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "Development build"
    }
}
