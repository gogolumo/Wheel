import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WheelMacOS

struct WheelApplicationsSettingsView: View {
    @ObservedObject var viewModel: WheelAppViewModel
    @State private var pinError: String?

    var body: some View {
        let slots = viewModel.wheelSlots

        WheelSettingsPage(
            title: "Applications",
            subtitle: "Pin applications to fixed sectors. Other sectors follow recent history."
        ) {
            Section("Sector assignments") {
                ForEach(0..<viewModel.settings.directionCount, id: \.self) { position in
                    assignmentRow(position: position, application: slots[position])
                }
            }

            if !hiddenPins.isEmpty {
                Section("Retained pins") {
                    Text(
                        "These slots are hidden by the current direction count. Increase the number "
                            + "of directions to show them in their saved positions again."
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)

                    ForEach(hiddenPins) { slot in
                        HStack(spacing: WheelVisualTokens.Spacing.regular) {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: WheelVisualTokens.Spacing.xs) {
                                Text(slot.application.localizedName)
                                    .lineLimit(1)
                                Text("Slot \(slot.position + 1) · Hidden, retained")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            unpinButton(position: slot.position, name: slot.application.localizedName)
                        }
                    }
                }
            }

            if let pinError {
                Section {
                    Label(pinError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
            }

            Section {
                Text(
                    "Choosing an already pinned application moves it to the new slot. "
                        + "Changing direction count keeps every hidden pin saved."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var hiddenPins: [WheelPinnedSlot] {
        viewModel.pinnedSlots.slots.filter { $0.position >= viewModel.settings.directionCount }
    }

    private func assignmentRow(position: Int, application: WheelApplicationContext?) -> some View {
        let pin = viewModel.pinnedApplication(at: position)

        return HStack(spacing: WheelVisualTokens.Spacing.regular) {
            VStack(alignment: .leading, spacing: WheelVisualTokens.Spacing.xs) {
                Text("Slot \(position + 1)")
                    .font(.callout.weight(.medium))
                Text(positionLabel(position))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 76, alignment: .leading)

            if let application {
                WheelApplicationIcon(application: application, size: 28)
            } else {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }

            VStack(alignment: .leading, spacing: WheelVisualTokens.Spacing.xs) {
                Text(pin?.localizedName ?? application?.localizedName ?? "Automatic")
                    .lineLimit(1)
                if pin != nil {
                    Label(
                        "Pinned · \(runStateLabel(application?.runState))",
                        systemImage: "pin.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text("Recent history")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: WheelVisualTokens.Spacing.medium)

            Button(pin == nil ? "Choose…" : "Replace…") {
                chooseApplication(for: position)
            }
            .disabled(viewModel.fixture != nil)
            .accessibilityLabel("\(pin == nil ? "Choose application for" : "Replace application in") slot \(position + 1)")

            if let pin {
                unpinButton(position: position, name: pin.localizedName)
            }
        }
        .padding(.vertical, WheelVisualTokens.Spacing.xs)
    }

    private func unpinButton(position: Int, name: String) -> some View {
        Button {
            viewModel.unpinApplication(at: position)
            pinError = nil
        } label: {
            Image(systemName: "pin.slash")
        }
        .buttonStyle(.borderless)
        .disabled(viewModel.fixture != nil)
        .help("Unpin \(name)")
        .accessibilityLabel("Unpin \(name) from slot \(position + 1)")
    }

    private func runStateLabel(_ runState: WheelApplicationRunState?) -> String {
        WheelApplicationPresentation(runState: runState ?? .unavailable, isPinned: true).statusText
    }

    private func positionLabel(_ position: Int) -> String {
        let count = viewModel.settings.directionCount
        let compass = ["Right", "Down Right", "Down", "Down Left", "Left", "Up Left", "Up", "Up Right"]
        if count == 2 || count == 4 || count == 8 {
            return compass[position * (8 / count)]
        }
        let degrees = Int((WheelSectorLayout.angle(for: position, sectorCount: count) * 180 / .pi).rounded())
        return "\(degrees)°"
    }

    private func chooseApplication(for position: Int) {
        guard viewModel.fixture == nil else { return }

        let panel = NSOpenPanel()
        panel.title = "Choose an application for Wheel"
        panel.message = "Select a macOS application to pin to slot \(position + 1)."
        panel.prompt = "Pin"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try viewModel.pinApplication(at: url, to: position)
            pinError = nil
        } catch {
            pinError = error.localizedDescription
        }
    }
}
