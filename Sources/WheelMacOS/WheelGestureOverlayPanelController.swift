import AppKit
import Combine
import QuartzCore

private final class WheelNonactivatingOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Owns Wheel's single click-through HUD panel.
///
/// The panel is deliberately separate from input capture. It observes only the
/// aggregate overlay state published by `WheelAppViewModel`, never raw events or
/// pointer coordinates.
@MainActor
public final class WheelGestureOverlayPanelController {
    public typealias ScreenProvider = () -> NSScreen?

    public static let panelSize = NSSize(width: 404, height: 160)

    public private(set) var panel: NSPanel
    public private(set) var isObserving = false

    private let viewModel: WheelAppViewModel
    private let screenProvider: ScreenProvider
    private var overlayStateCancellable: AnyCancellable?
    private var animationGeneration = 0
    private var hasShutdown = false

    public convenience init(
        viewModel: WheelAppViewModel,
        contentView: NSView
    ) {
        self.init(
            viewModel: viewModel,
            contentView: contentView,
            screenProvider: Self.screenContainingPointer
        )
    }

    public init(
        viewModel: WheelAppViewModel,
        contentView: NSView,
        screenProvider: @escaping ScreenProvider
    ) {
        self.viewModel = viewModel
        self.screenProvider = screenProvider

        let panel = WheelNonactivatingOverlayPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle
        ]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.ignoresMouseEvents = true
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.isExcludedFromWindowsMenu = true
        panel.tabbingMode = .disallowed
        panel.animationBehavior = .none
        panel.contentView = contentView
        contentView.frame = NSRect(origin: .zero, size: Self.panelSize)

        self.panel = panel
    }

    public func start() {
        guard !isObserving, !hasShutdown else { return }

        isObserving = true
        overlayStateCancellable = viewModel.$overlayState
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.apply(state)
            }
    }

    public func shutdown() {
        guard !hasShutdown else { return }

        hasShutdown = true
        isObserving = false
        overlayStateCancellable?.cancel()
        overlayStateCancellable = nil
        animationGeneration += 1
        panel.alphaValue = 0
        panel.orderOut(nil)
        panel.close()
    }

    static func frame(
        panelSize: NSSize = WheelGestureOverlayPanelController.panelSize,
        in visibleFrame: NSRect
    ) -> NSRect {
        NSRect(
            x: visibleFrame.midX - panelSize.width / 2,
            y: visibleFrame.midY - panelSize.height / 2,
            width: panelSize.width,
            height: panelSize.height
        )
    }

    func apply(
        _ state: WheelGestureOverlayState,
        animated: Bool = true
    ) {
        animationGeneration += 1
        let generation = animationGeneration
        let shouldAnimate = animated
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        guard state.isVisible else {
            hide(generation: generation, animated: shouldAnimate)
            return
        }

        if let screen = screenProvider() {
            panel.setFrame(Self.frame(in: screen.visibleFrame), display: false)
        }

        guard !panel.isVisible else {
            panel.alphaValue = 1
            return
        }

        if shouldAnimate {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        } else {
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        }
    }

    private func hide(generation: Int, animated: Bool) {
        guard panel.isVisible else {
            panel.alphaValue = 0
            return
        }

        guard animated else {
            panel.alphaValue = 0
            panel.orderOut(nil)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.animationGeneration == generation else { return }
                self.panel.orderOut(nil)
            }
        }
    }

    private static func screenContainingPointer() -> NSScreen? {
        let pointerLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            screen.frame.contains(pointerLocation)
        } ?? NSScreen.main ?? NSScreen.screens.first
    }
}
