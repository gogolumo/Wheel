import SwiftUI
import WheelMacOS

/// Shared production ring used by the gesture overlay and the read-only Settings preview.
struct WheelRingView: View {
    let slots: [WheelApplicationContext?]
    let pinnedIndices: Set<Int>
    let selectedIndex: Int?
    let isResult: Bool
    let centerText: String
    let triggerHint: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.wheelAccessibilityReview) private var accessibilityReview

    private var reduceSpatialMotion: Bool {
        reduceMotion || accessibilityReview?.reduceMotion == true
    }

    private var useStructuralSelection: Bool {
        differentiateWithoutColor || accessibilityReview?.differentiateWithoutColor == true
    }

    static let diameter: CGFloat = 492

    var body: some View {
        ZStack {
            WheelGlassSurface(shape: Circle(), role: .overlay)

            // Static vector segmentation shares the shell's one backdrop material.
            ForEach(slots.indices, id: \.self) { index in
                sector(at: index)
            }

            WheelCenterHub(text: centerText, triggerHint: triggerHint)
        }
        .frame(width: Self.diameter, height: Self.diameter)
        .animation(
            reduceSpatialMotion ? nil : WheelVisualTokens.Motion.selection,
            value: selectedIndex
        )
        .animation(
            reduceSpatialMotion ? nil : WheelVisualTokens.Motion.selection,
            value: isResult
        )
    }

    private func sector(at index: Int) -> some View {
        let selected = selectedIndex == index
        let application = slots[index]
        let shape = WheelSectorShape(index: index, count: slots.count)
        let angle = WheelSectorLayout.angle(for: index, sectorCount: slots.count)
        let offset = selected && !reduceSpatialMotion ? WheelVisualTokens.Motion.selectedOffset : 0
        let presentation = application.map {
            WheelApplicationPresentation(runState: $0.runState, isPinned: pinnedIndices.contains(index))
        }

        return ZStack {
            shape.fill(selected ? WheelVisualTokens.Optical.selectedWash : WheelVisualTokens.Optical.restingWash)
            if contrast == .increased || accessibilityReview?.increaseContrast == true {
                shape.strokeBorder(Color.primary.opacity(selected ? 0.9 : 0.5), lineWidth: selected ? 2.5 : 1)
            } else {
                shape.strokeBorder(
                    WheelVisualTokens.Optical.rim(dark: colorScheme == .dark, emphasized: selected),
                    lineWidth: selected ? (useStructuralSelection ? 2.5 : 1.5) : 0.75
                )
            }

            if let application, let presentation {
                WheelSectorContent(
                    application: application,
                    presentation: presentation,
                    selected: selected,
                    compact: slots.count >= 10,
                    showSelectionMarker: selected && application.runState != .unavailable
                )
                .position(position(angle: angle, radius: 169))
            }
        }
        .frame(width: Self.diameter, height: Self.diameter)
        .scaleEffect(selected && !reduceSpatialMotion ? WheelVisualTokens.Motion.selectedScale : 1)
        .offset(x: offset * CGFloat(cos(angle)), y: offset * CGFloat(sin(angle)))
        .opacity(isResult && !selected ? WheelVisualTokens.Optical.resultRecession : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(application.map { "\($0.localizedName), \(presentation?.accessibilityState ?? "")" } ?? "Empty sector")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHidden(application == nil)
    }

    private func position(angle: Double, radius: CGFloat) -> CGPoint {
        CGPoint(
            x: Self.diameter / 2 + radius * CGFloat(cos(angle)),
            y: Self.diameter / 2 + radius * CGFloat(sin(angle))
        )
    }
}

private struct WheelSectorContent: View {
    let application: WheelApplicationContext
    let presentation: WheelApplicationPresentation
    let selected: Bool
    let compact: Bool
    let showSelectionMarker: Bool

    var body: some View {
        VStack(spacing: WheelVisualTokens.Spacing.small) {
            WheelApplicationIcon(application: application, size: compact ? 38 : 48)
                .opacity(application.runState == .unavailable ? 0.55 : 1)
            Text(application.localizedName)
                .font(.system(size: compact ? 10 : 12, weight: selected ? .semibold : .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: compact ? 68 : 96)
            HStack(spacing: WheelVisualTokens.Spacing.xs) {
                if presentation.isPinned {
                    Image(systemName: "pin.fill")
                }
                if application.runState != .running {
                    Image(systemName: presentation.symbolName)
                }
                if showSelectionMarker {
                    Image(systemName: "checkmark")
                        .fontWeight(.bold)
                }
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
            // Stable height prevents labels from moving when a state marker changes.
            .frame(height: 10)
        }
        .accessibilityHidden(true)
    }
}
