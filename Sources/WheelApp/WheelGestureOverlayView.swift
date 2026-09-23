import SwiftUI
import WheelDomain
import WheelMacOS

struct WheelGestureOverlayView: View {
    @ObservedObject var viewModel: WheelAppViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        HStack(spacing: 22) {
            directionIndicator(.left)

            VStack(spacing: 8) {
                Text(triggerKeycap)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.94))
                            .shadow(color: .black.opacity(0.16), radius: 3, y: 1)
                    )

                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.7)
            }
            .frame(minWidth: 118)

            directionIndicator(.right)
        }
        .padding(.horizontal, 26)
        .frame(width: 380, height: 136)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        }
        .padding(12)
        .shadow(color: .black.opacity(0.26), radius: 20, y: 8)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.12),
            value: viewModel.overlayContentState
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func directionIndicator(_ direction: Direction) -> some View {
        let selected = isSelected(direction)
        let subdued = isShowingResult && !selected

        return ZStack {
            Circle()
                .fill(selected ? Color.accentColor : Color.primary.opacity(0.08))
                .overlay {
                    if differentiateWithoutColor && selected {
                        Circle().strokeBorder(.primary, lineWidth: 3)
                    }
                }

            Image(systemName: direction == .left ? "arrow.left" : "arrow.right")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .frame(width: 64, height: 64)
        .opacity(subdued ? 0.32 : 1)
        .scaleEffect(selected ? 1.06 : 1)
    }

    private var triggerKeycap: String {
        switch viewModel.configuration.triggerType {
        case .rightOption:
            return "Right ⌥"
        case .capsLock:
            return "Caps ⇪"
        case .mouseSideButton:
            return "Mouse"
        }
    }

    private var statusText: String {
        switch viewModel.overlayContentState {
        case .hidden, .triggerHeld:
            return "Hold and move"
        case .resultLeft:
            return "Left"
        case .resultRight:
            return "Right"
        case .resultNone:
            return "No movement"
        }
    }

    private var accessibilityLabel: String {
        switch viewModel.overlayContentState {
        case .hidden, .triggerHeld:
            return "Wheel gesture active. Hold the trigger and move left or right."
        case .resultLeft:
            return "Wheel recognized left. Navigation is not connected yet."
        case .resultRight:
            return "Wheel recognized right. Navigation is not connected yet."
        case .resultNone:
            return "Wheel detected no directional movement."
        }
    }

    private var isShowingResult: Bool {
        switch viewModel.overlayContentState {
        case .resultLeft, .resultRight, .resultNone:
            return true
        case .hidden, .triggerHeld:
            return false
        }
    }

    private func isSelected(_ direction: Direction) -> Bool {
        switch (viewModel.overlayContentState, direction) {
        case (.resultLeft, .left), (.resultRight, .right):
            return true
        default:
            return false
        }
    }
}
