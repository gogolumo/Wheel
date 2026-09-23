import AppKit
import Combine
import SwiftUI
import WheelMacOS

/// Owns the small, nonactivating gesture surface shown above other apps.
///
/// The panel never becomes key, accepts no input, and observes only the
/// view model's boolean held state. It therefore cannot steal focus or collect
/// window titles, pointer coordinates, typed content, or application identity.
@MainActor
final class WheelGestureHUDController {
    private let panel: NSPanel
    private var subscriptions = Set<AnyCancellable>()

    init(viewModel: WheelAppViewModel) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 92),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .transient
        ]
        panel.contentView = NSHostingView(
            rootView: WheelGestureHUDView(viewModel: viewModel)
        )

        viewModel.$isGestureActive
            .removeDuplicates()
            .sink { [weak self] isActive in
                self?.setVisible(isActive)
            }
            .store(in: &subscriptions)
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func setVisible(_ isVisible: Bool) {
        guard isVisible else {
            panel.orderOut(nil)
            return
        }

        positionPanel()
        panel.orderFrontRegardless()
    }

    private func positionPanel() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let visibleFrame = screen.visibleFrame
        let origin = NSPoint(
            x: visibleFrame.midX - panel.frame.width / 2,
            y: visibleFrame.minY + min(140, visibleFrame.height * 0.16)
        )
        panel.setFrameOrigin(origin)
    }
}

private struct WheelGestureHUDView: View {
    @ObservedObject var viewModel: WheelAppViewModel

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "cursorarrow.motionlines")
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(.indigo)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Wheel active")
                    .font(.headline)
                Text("Move left or right, then release")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(viewModel.lastTriggerSignalIsDown == true ? "DOWN" : "HELD")
                .font(.caption.monospaced().weight(.bold))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.indigo.opacity(0.14), in: Capsule())
                .foregroundStyle(.indigo)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(width: 300, height: 92)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.16))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Wheel gesture active. Move left or right, then release.")
    }
}
