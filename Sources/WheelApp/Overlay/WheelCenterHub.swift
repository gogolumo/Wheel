import SwiftUI

struct WheelCenterHub: View {
    let text: String
    let triggerHint: String

    var body: some View {
        VStack(spacing: WheelVisualTokens.Spacing.medium) {
            HStack(spacing: WheelVisualTokens.Spacing.medium) {
                WheelBrandMark(size: 24)
                Text(WheelBrand.name)
                    .font(.system(size: 25, weight: .medium))
                    .tracking(-0.5)
            }
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
