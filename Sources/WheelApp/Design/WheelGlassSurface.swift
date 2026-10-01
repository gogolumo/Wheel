import SwiftUI

/// One compatibility boundary for glass. No per-sector blurs or external renderer.
struct WheelGlassSurface<S: InsettableShape>: View {
    let shape: S
    var role: WheelSurfaceRole = .panel
    var emphasized = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var needsOpaqueSurface: Bool {
        reduceTransparency || contrast == .increased
    }

    var body: some View {
        surface
            .overlay {
                if !needsOpaqueSurface {
                    shape.fill(
                        LinearGradient(
                            colors: [
                                WheelVisualTokens.Optical.highlight.opacity(0.08),
                                .clear,
                                WheelVisualTokens.Optical.coolEdge.opacity(0.035)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            }
            .overlay {
                if needsOpaqueSurface {
                    shape.strokeBorder(Color.primary.opacity(0.65), lineWidth: 1.5)
                } else {
                    shape.strokeBorder(
                        WheelVisualTokens.Optical.rim(
                            dark: colorScheme == .dark,
                            emphasized: emphasized
                        ),
                        lineWidth: emphasized ? 1.5 : 1
                    )
                }
            }
            .shadow(
                color: WheelVisualTokens.Optical.shadow.opacity(
                    colorScheme == .dark ? 0.25 : 0.16
                ),
                radius: role.shadowRadius,
                y: role == .overlay ? 8 : 4
            )
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var surface: some View {
        if needsOpaqueSurface {
            shape.fill(Color(nsColor: .windowBackgroundColor))
        } else {
            compatibleGlass
        }
    }

    @ViewBuilder
    private var compatibleGlass: some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            shape.fill(.clear)
                .glassEffect(.regular, in: shape)
        } else {
            materialFallback
        }
        #else
        materialFallback
        #endif
    }

    private var materialFallback: some View {
        shape.fill(role.material)
            .overlay {
                // Native material adapts to the desktop; the wash anchors text contrast.
                shape.fill(
                    Color(nsColor: .windowBackgroundColor).opacity(
                        role == .overlay ? 0.14 : 0.24
                    )
                )
            }
    }
}

/// Optional style for small floating controls; Settings keeps native button styles.
struct WheelGlassButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, WheelVisualTokens.Spacing.regular)
            .padding(.vertical, WheelVisualTokens.Spacing.medium)
            .background {
                WheelGlassSurface(
                    shape: RoundedRectangle(cornerRadius: WheelVisualTokens.Radius.control),
                    role: .control,
                    emphasized: configuration.isPressed
                )
            }
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(
                reduceMotion ? nil : WheelVisualTokens.Motion.selection,
                value: configuration.isPressed
            )
    }
}
