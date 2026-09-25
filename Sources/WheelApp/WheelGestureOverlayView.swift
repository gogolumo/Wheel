import AppKit
import SwiftUI
import WheelMacOS

struct WheelGestureOverlayView: View {
    @ObservedObject var viewModel: WheelAppViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    private let canvasSize: CGFloat = 492
    private let applicationRadius: CGFloat = 166
    private let sectorRadius: CGFloat = 214

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.28), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.28), radius: 28, y: 12)

            sectorGuides

            ForEach(
                Array(viewModel.wheelApplications.enumerated()),
                id: \.element.id
            ) { index, application in
                applicationItem(application, index: index)
            }

            centerHub
        }
        .frame(width: canvasSize, height: canvasSize)
        .padding(14)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.12),
            value: viewModel.hoveredApplicationIndex
        )
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.12),
            value: viewModel.overlayContentState
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var sectorGuides: some View {
        ZStack {
            ForEach(0..<viewModel.settings.directionCount, id: \.self) { index in
                let point = position(
                    index: index,
                    count: viewModel.settings.directionCount,
                    radius: sectorRadius
                )

                Circle()
                    .fill(Color.primary.opacity(0.07))
                    .frame(width: 10, height: 10)
                    .position(point)
            }
        }
        .frame(width: canvasSize, height: canvasSize)
    }

    private func applicationItem(
        _ application: WheelApplicationContext,
        index: Int
    ) -> some View {
        let selected = selectedIndex == index
        let point = position(
            index: index,
            count: viewModel.settings.directionCount,
            radius: applicationRadius
        )

        return VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(
                        selected
                            ? Color.accentColor.opacity(0.24)
                            : Color(nsColor: .windowBackgroundColor).opacity(0.88)
                    )
                    .frame(width: 76, height: 76)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                selected
                                    ? Color.accentColor
                                    : Color.white.opacity(0.22),
                                lineWidth: selected ? 3 : 1
                            )
                    }

                applicationIcon(application)
                    .frame(width: 50, height: 50)

                if application.runState != .running {
                    Image(
                        systemName: application.runState == .terminated
                            ? "arrow.clockwise.circle.fill"
                            : "exclamationmark.circle.fill"
                    )
                    .font(.system(size: 19, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        application.runState == .terminated
                            ? Color.accentColor
                            : Color.orange,
                        Color(nsColor: .windowBackgroundColor)
                    )
                    .background(Circle().fill(Color(nsColor: .windowBackgroundColor)))
                }
            }

            Text(application.localizedName)
                .font(.caption.weight(selected ? .semibold : .medium))
                .lineLimit(1)
                .frame(width: 108)
                .foregroundStyle(selected ? .primary : .secondary)
        }
        .scaleEffect(selected ? 1.08 : 1)
        .opacity(
            viewModel.overlayContentState == .resultSelection && !selected
                ? 0.42
                : 1
        )
        .position(point)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func applicationIcon(
        _ application: WheelApplicationContext
    ) -> some View {
        if let url = application.applicationURL {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "app")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(8)
        }
    }

    private var centerHub: some View {
        VStack(spacing: 8) {
            Text(triggerKeycap)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.94))
                        .shadow(color: .black.opacity(0.14), radius: 3, y: 1)
                )

            Text(statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 132)

            if viewModel.wheelApplications.isEmpty {
                Text("Switch between apps first")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text(
                    "\(viewModel.settings.directionCount) directions · "
                        + "\(viewModel.wheelApplications.count) apps"
                )
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
            }
        }
        .padding(18)
        .frame(width: 170, height: 142)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(.white.opacity(0.24), lineWidth: 1)
        }
    }

    private var selectedIndex: Int? {
        switch viewModel.overlayContentState {
        case .resultSelection:
            return viewModel.selectedApplicationIndex
        case .hidden, .triggerHeld, .resultLeft, .resultRight, .resultNone:
            return viewModel.hoveredApplicationIndex
        }
    }

    private func position(
        index: Int,
        count: Int,
        radius: CGFloat
    ) -> CGPoint {
        let angle = WheelSectorLayout.angle(
            for: index,
            sectorCount: count
        )
        let center = canvasSize / 2

        return CGPoint(
            x: center + radius * CGFloat(cos(angle)),
            y: center + radius * CGFloat(sin(angle))
        )
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
            if let index = viewModel.hoveredApplicationIndex,
               viewModel.wheelApplications.indices.contains(index)
            {
                return viewModel.wheelApplications[index].localizedName
            }
            return "Move toward an app"
        case .resultSelection:
            if let name = viewModel.lastApplicationAction {
                return "Opening \(name)"
            }
            return "Opening app"
        case .resultLeft:
            return "Left"
        case .resultRight:
            return "Right"
        case .resultNone:
            return "No selection"
        }
    }

    private var accessibilityLabel: String {
        switch viewModel.overlayContentState {
        case .hidden, .triggerHeld:
            return "Wheel is open. Move toward an application and release the trigger."
        case .resultSelection:
            return "Wheel selected \(viewModel.lastApplicationAction ?? "an application")."
        case .resultLeft:
            return "Wheel recognized left."
        case .resultRight:
            return "Wheel recognized right."
        case .resultNone:
            return "Wheel detected no application selection."
        }
    }
}
