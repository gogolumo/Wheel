import SwiftUI
import WheelMacOS

struct WheelGestureOverlayView: View {
    @ObservedObject var viewModel: WheelAppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.wheelAccessibilityReview) private var accessibilityReview

    private let panelSize = WheelGestureOverlayPanelController.panelSize

    private var reduceSpatialMotion: Bool {
        reduceMotion || accessibilityReview?.reduceMotion == true
    }

    var body: some View {
        // Resolve runtime destinations once per render, rather than once per sector.
        let slots = viewModel.wheelSlots
        let index = selectedIndex
        let application = index.flatMap { slots.indices.contains($0) ? slots[$0] : nil }
        let pinnedIndices = Set(slots.indices.filter { viewModel.isPinnedSlot($0) })

        GeometryReader { geometry in
            let scale = min(1, geometry.size.width / panelSize.width, geometry.size.height / panelSize.height)
            composition(slots: slots, index: index, application: application, pinnedIndices: pinnedIndices)
                .scaleEffect(scale)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .accessibilityLabel("Wheel application selection")
    }

    private func composition(
        slots: [WheelApplicationContext?],
        index: Int?,
        application: WheelApplicationContext?,
        pinnedIndices: Set<Int>
    ) -> some View {
        HStack(spacing: WheelVisualTokens.Spacing.xxl) {
            WheelRingView(
                slots: slots,
                pinnedIndices: pinnedIndices,
                selectedIndex: index,
                isResult: viewModel.overlayContentState == .resultSelection,
                centerText: centerText(application: application, empty: slots.allSatisfy { $0 == nil }),
                triggerHint: viewModel.configuration.triggerType.keycapLabel
            )

            WheelContextPanel(
                application: application,
                isPinned: index.map { pinnedIndices.contains($0) } ?? false,
                isResult: viewModel.overlayContentState == .resultSelection
            )
        }
        .padding(14)
        .frame(width: panelSize.width, height: panelSize.height)
        .scaleEffect(viewModel.overlayState.isVisible || reduceSpatialMotion ? 1 : 0.98)
        .animation(
            reduceSpatialMotion ? nil : WheelVisualTokens.Motion.entrance,
            value: viewModel.overlayState.isVisible
        )
        .overlay(alignment: .bottomTrailing) {
            if let label = viewModel.fixtureLabel {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(.background, in: Capsule())
                    .padding(14)
            }
        }
    }

    private var selectedIndex: Int? {
        viewModel.overlayContentState == .resultSelection
            ? viewModel.selectedApplicationIndex
            : viewModel.hoveredApplicationIndex
    }

    private func centerText(application: WheelApplicationContext?, empty: Bool) -> String {
        switch viewModel.overlayContentState {
        case .hidden, .triggerHeld:
            return application?.localizedName ?? (empty ? "Switch between apps to build history" : "Move to select")
        case .resultSelection:
            // Acknowledges selection only: asynchronous activation may still fail.
            return application.map { "Selected \($0.localizedName)" } ?? "Selection sent"
        case .resultLeft: return "Previous context"
        case .resultRight: return "Next context"
        case .resultNone: return "No selection"
        }
    }
}
