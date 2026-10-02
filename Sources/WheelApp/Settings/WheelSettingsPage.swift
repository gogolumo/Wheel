import SwiftUI

/// Native Forms own content surfaces; glass is reserved for navigation and transient UI.
struct WheelSettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: WheelVisualTokens.Spacing.small) {
                Text(title)
                    .font(.title.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, WheelVisualTokens.Spacing.xxl)
            .padding(.top, WheelVisualTokens.Spacing.xxl)
            .padding(.bottom, WheelVisualTokens.Spacing.medium)

            Form { content }
                .formStyle(.grouped)
        }
    }
}
