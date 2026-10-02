import SwiftUI

struct WheelCenterHub: View {
    let text: String
    let triggerHint: String

    var body: some View {
        VStack(spacing: WheelVisualTokens.Spacing.medium) {
            Text("Wheel")
                .font(.system(size: 27, weight: .medium))
                .tracking(-0.5)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(width: 134)
            Text(triggerHint)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.top, WheelVisualTokens.Spacing.xs)
        }
        .frame(width: 176, height: 176)
        .background {
            WheelGlassSurface(shape: Circle(), role: .hub, emphasized: true)
        }
        .accessibilityElement(children: .combine)
    }
}
