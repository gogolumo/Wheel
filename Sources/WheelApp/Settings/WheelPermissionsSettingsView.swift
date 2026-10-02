import SwiftUI
import WheelMacOS

struct WheelPermissionsSettingsView: View {
    @ObservedObject var viewModel: WheelAppViewModel

    var body: some View {
        WheelSettingsPage(
            title: "Permissions",
            subtitle: "One permission for global gestures. Your application data stays local."
        ) {
            Section("Input Monitoring") {
                LabeledContent("Access") {
                    Label(
                        viewModel.permissionGranted ? "Granted" : "Required",
                        systemImage: viewModel.permissionGranted
                            ? "checkmark.shield" : "exclamationmark.shield"
                    )
                    .foregroundStyle(viewModel.permissionGranted ? Color.primary : Color.orange)
                }

                Text(
                    "Wheel needs Input Monitoring to observe the configured trigger and pointer "
                        + "movement outside its own windows. Input is observed without blocking it."
                )
                .font(.callout)
                .foregroundStyle(.secondary)

                HStack {
                    if !viewModel.permissionGranted {
                        Button("Request Access", action: viewModel.requestPermission)
                            .disabled(!viewModel.canRequestPermission)
                    }
                    Button("Open Privacy Settings", action: WheelSystemSettings.openInputMonitoring)
                        .disabled(viewModel.fixture != nil)
                    Spacer()
                    Button("Check Again", action: viewModel.refreshPermission)
                        .disabled(viewModel.fixture != nil)
                }

                if !viewModel.permissionGranted {
                    Text(
                        "Enable Wheel in System Settings → Privacy & Security → Input Monitoring, "
                            + "then return here and check again."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if !viewModel.isEnabled {
                    Text("Enable Wheel in General to request access and start global gestures.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Application-level access") {
                LabeledContent("Accessibility", value: "Not required")
                LabeledContent("Screen Recording", value: "Not required")
                Text(
                    "This build switches or reopens applications using macOS application identity. "
                        + "It does not capture windows or screenshots and does not restore individual tabs or documents."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            Section("Running from source") {
                Text(
                    "A launch through swift run may use Terminal’s permission. The installed Wheel.app "
                        + "has its own Input Monitoring entry; a local rebuild may require granting access again."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}
