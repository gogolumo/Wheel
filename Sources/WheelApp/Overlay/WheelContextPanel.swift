import SwiftUI
import WheelMacOS

/// Read-only because the gesture HUD is intentionally nonactivating and click-through.
struct WheelContextPanel: View {
    let application: WheelApplicationContext?
    let isPinned: Bool
    let isResult: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: WheelVisualTokens.Spacing.xl) {
            if let application {
                applicationDetails(application)
            } else {
                guidance
            }
        }
        .padding(WheelVisualTokens.Spacing.xxl)
        .frame(width: 276, height: 352, alignment: .topLeading)
        .background {
            WheelGlassSurface(
                shape: RoundedRectangle(cornerRadius: WheelVisualTokens.Radius.panel),
                role: .context
            )
        }
        .accessibilityElement(children: .combine)
    }

    private func applicationDetails(_ application: WheelApplicationContext) -> some View {
        let presentation = WheelApplicationPresentation(runState: application.runState, isPinned: isPinned)
        return VStack(alignment: .leading, spacing: WheelVisualTokens.Spacing.xl) {
            HStack(spacing: WheelVisualTokens.Spacing.regular) {
                WheelApplicationIcon(application: application, size: 44)
                Text(application.localizedName)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
            }

            Divider()

            Label(presentation.statusText, systemImage: presentation.symbolName)
                .font(.callout)

            if isPinned {
                Label("Pinned", systemImage: "pin.fill")
                    .font(.callout)
            }

            Text(explanation(for: application.runState))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if let instruction = presentation.releaseInstruction {
                Label(isResult ? "Selection sent" : instruction, systemImage: isResult ? "checkmark" : "arrow.turn.down.right")
                    .font(.callout.weight(.medium))
            } else {
                Label("Choose a replacement in Settings", systemImage: "gearshape")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var guidance: some View {
        VStack(alignment: .leading, spacing: WheelVisualTokens.Spacing.xl) {
            Image(systemName: "cursorarrow.motionlines")
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Your apps, in context.")
                .font(.title3.weight(.medium))
            Text("Move toward an application. Release the trigger to switch or reopen it.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Label("Pins keep their place", systemImage: "pin")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func explanation(for state: WheelApplicationRunState) -> String {
        switch state {
        case .running: return "Switch to this application. Its windows remain managed by macOS."
        case .terminated: return "Wheel remembers this application and can reopen it."
        case .unavailable:
            return isPinned
                ? "This application could not be found. Its pinned position is preserved."
                : "This application is currently unavailable."
        }
    }
}
