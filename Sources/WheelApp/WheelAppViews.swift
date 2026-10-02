import AppKit
import SwiftUI
import WheelMacOS

struct WheelMenuBarLabel: View {
    @ObservedObject var viewModel: WheelAppViewModel

    var body: some View {
        Label {
            Text("\(WheelBrand.name) — \(displayedStatus)")
        } icon: {
            Image(nsImage: WheelBrand.menuBarTemplateImage)
                .renderingMode(.template)
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel("Wheel: \(displayedStatus)")
        .help("Wheel — \(displayedStatus)")
    }

    private var displayedStatus: String {
        viewModel.isGestureActive ? "Trigger Held" : viewModel.status.rawValue
    }
}

/// A transient control surface; detailed configuration and diagnostics live in Settings.
struct WheelMenuBarView: View {
    @ObservedObject var viewModel: WheelAppViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: WheelVisualTokens.Spacing.regular) {
            HStack(spacing: WheelVisualTokens.Spacing.regular) {
                WheelMark(size: 32)
                VStack(alignment: .leading, spacing: WheelVisualTokens.Spacing.xs) {
                    Text("Wheel")
                        .font(.headline)
                    Text(viewModel.configuration.triggerType.keycapLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                WheelStatusLabel(
                    status: viewModel.status,
                    isGestureActive: viewModel.isGestureActive
                )
            }

            runtimeControl

            if let errorMessage = viewModel.errorMessage, viewModel.status == .error {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let application = viewModel.applicationHistory.first {
                Divider()
                HStack(spacing: WheelVisualTokens.Spacing.regular) {
                    WheelApplicationIcon(application: application, size: 28)
                    VStack(alignment: .leading, spacing: WheelVisualTokens.Spacing.xs) {
                        Text("Recent application")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(application.localizedName)
                            .font(.callout)
                            .lineLimit(1)
                    }
                    Spacer()
                }
            }

            HStack {
                Label("Input Monitoring", systemImage: "hand.raised")
                Spacer()
                Label(
                    viewModel.permissionGranted ? "Granted" : "Required",
                    systemImage: viewModel.permissionGranted
                        ? "checkmark.circle" : "exclamationmark.circle"
                )
                .foregroundStyle(viewModel.permissionGranted ? Color.secondary : Color.orange)
            }
            .font(.caption)

            if !viewModel.permissionGranted {
                Button("Open Privacy Settings", action: WheelSystemSettings.openInputMonitoring)
                    .disabled(viewModel.fixture != nil)
            }

            Divider()

            HStack {
                Button("Open Settings…") {
                    openWindow(id: "dashboard")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(",", modifiers: .command)
                Spacer()
                Button("Quit Wheel") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .controlSize(.small)

            if viewModel.fixtureLabel != nil {
                Text("Fixture preview")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(WheelVisualTokens.Spacing.large)
        .frame(width: 300)
        .background {
            WheelGlassSurface(
                shape: RoundedRectangle(
                    cornerRadius: WheelVisualTokens.Radius.context,
                    style: .continuous
                ),
                role: .popover
            )
        }
    }

    @ViewBuilder
    private var runtimeControl: some View {
        if !viewModel.isEnabled {
            Button {
                viewModel.setEnabled(true)
            } label: {
                Label("Enable Wheel", systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.fixture != nil)
        } else if viewModel.isPaused {
            Button(action: viewModel.resume) {
                Label("Resume Wheel", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!viewModel.canResume)
        } else if viewModel.status == .needsPermission {
            Button(action: viewModel.requestPermission) {
                Label("Allow Input Monitoring", systemImage: "hand.raised")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!viewModel.canRequestPermission)
        } else if viewModel.status == .error {
            Button(action: viewModel.refreshPermission) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.fixture != nil)
        } else {
            Button(action: viewModel.pause) {
                Label("Pause Wheel", systemImage: "pause.fill")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!viewModel.canPause)
        }
    }
}

struct WheelDashboardView: View {
    enum Section: String, CaseIterable, Identifiable {
        case general = "General"
        case layout = "Wheel Layout"
        case applications = "Applications"
        case history = "History"
        case appearance = "Appearance"
        case permissions = "Permissions"
        case advanced = "Advanced"
        case about = "About"

        var id: Self { self }

        var symbolName: String {
            switch self {
            case .general: return "gearshape"
            case .layout: return "circle.hexagongrid"
            case .applications: return "app.badge"
            case .history: return "clock.arrow.circlepath"
            case .appearance: return "circle.lefthalf.filled"
            case .permissions: return "hand.raised"
            case .advanced: return "slider.horizontal.3"
            case .about: return "info.circle"
            }
        }
    }

    @ObservedObject var viewModel: WheelAppViewModel
    @State private var selection: Section?

    init(viewModel: WheelAppViewModel, initialSection: Section = .general) {
        self.viewModel = viewModel
        _selection = State(initialValue: initialSection)
    }

    var body: some View {
        NavigationSplitView {
            // The sidebar's branding must not turn the native List's preferred
            // height into a larger minimum window size. Let the List scroll in
            // the actual sidebar viewport, just as Forms do in the detail pane.
            GeometryReader { geometry in
                sidebar
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height,
                        alignment: .topLeading
                    )
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            // A grouped Form's intrinsic height includes all of its rows. Keep
            // that height out of the native split view's minimum-size calculation
            // and give each page the actual detail viewport to scroll within.
            GeometryReader { geometry in
                Group {
                    switch selection ?? .general {
                    case .general: WheelGeneralSettingsView(viewModel: viewModel)
                    case .layout: WheelLayoutSettingsView(viewModel: viewModel)
                    case .applications: WheelApplicationsSettingsView(viewModel: viewModel)
                    case .history: WheelHistorySettingsView(viewModel: viewModel)
                    case .appearance: WheelAppearanceSettingsView()
                    case .permissions: WheelPermissionsSettingsView(viewModel: viewModel)
                    case .advanced: WheelAdvancedSettingsView(viewModel: viewModel)
                    case .about: WheelAboutSettingsView()
                    }
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: .topLeading
                )
            }
        }
        .frame(minWidth: 760, minHeight: 540)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: WheelVisualTokens.Spacing.regular) {
                WheelMark(size: 34)
                Text(WheelBrand.name)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, WheelVisualTokens.Spacing.large)
            .padding(.top, WheelVisualTokens.Spacing.large)

            Text(WheelBrand.tagline)
                .font(.caption)
                .foregroundStyle(WheelBrand.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, WheelVisualTokens.Spacing.large)
                .padding(.top, WheelVisualTokens.Spacing.medium)
                .padding(.bottom, WheelVisualTokens.Spacing.large)

            List(Section.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.symbolName)
                    .tag(section)
            }
            .listStyle(.sidebar)

            WheelStatusLabel(
                status: viewModel.status,
                isGestureActive: viewModel.isGestureActive
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(WheelVisualTokens.Spacing.large)

            if viewModel.fixtureLabel != nil {
                Label("Fixture preview", systemImage: "camera.viewfinder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, WheelVisualTokens.Spacing.large)
                    .padding(.bottom, WheelVisualTokens.Spacing.large)
            }
        }
    }
}
