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
    public typealias VisibleFrameProvider = () -> NSRect?

    /// 492 pt ring, 24 pt gap, 276 pt detail surface, and 14 pt edge padding.
    public static let panelSize = NSSize(width: 820, height: 520)

    public private(set) var panel: NSPanel
    public private(set) var isObserving = false

    private let viewModel: WheelAppViewModel
    private let visibleFrameProvider: VisibleFrameProvider
    private let notificationCenter: NotificationCenter
    private var overlayStateCancellable: AnyCancellable?
    private var screenParametersCancellable: AnyCancellable?
    private var animationGeneration = 0
    private var hasShutdown = false

    public convenience init(
        viewModel: WheelAppViewModel,
        contentView: NSView
    ) {
        self.init(
            viewModel: viewModel,
            contentView: contentView,
            visibleFrameProvider: Self.defaultVisibleFrame,
            notificationCenter: .default
        )
    }

    public init(
        viewModel: WheelAppViewModel,
        contentView: NSView,
        visibleFrameProvider: @escaping VisibleFrameProvider,
        notificationCenter: NotificationCenter = .default
    ) {
        self.viewModel = viewModel
        self.visibleFrameProvider = visibleFrameProvider
        self.notificationCenter = notificationCenter

        let panel = WheelNonactivatingOverlayPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
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
        panel.level = .statusBar
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
        screenParametersCancellable = notificationCenter.publisher(
            for: NSApplication.didChangeScreenParametersNotification
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.repositionVisiblePanel()
        }
    }

    public func shutdown() {
        guard !hasShutdown else { return }

        hasShutdown = true
        isObserving = false
        overlayStateCancellable?.cancel()
        overlayStateCancellable = nil
        screenParametersCancellable?.cancel()
        screenParametersCancellable = nil
        animationGeneration += 1
        panel.alphaValue = 0
        panel.orderOut(nil)
        panel.close()
    }

    static func frame(
        panelSize: NSSize,
        in visibleFrame: NSRect
    ) -> NSRect {
        // Fit the composition on small displays without reading pointer coordinates.
        let scale = min(
            1,
            max(1, visibleFrame.width - 32) / panelSize.width,
            max(1, visibleFrame.height - 32) / panelSize.height
        )
        let size = NSSize(width: panelSize.width * scale, height: panelSize.height * scale)
        return NSRect(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
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

        repositionPanel()

        guard !panel.isVisible else {
            panel.alphaValue = 1
            return
        }

        if shouldAnimate {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
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

    private func repositionVisiblePanel() {
        guard panel.isVisible else { return }

        repositionPanel()
    }

    private func repositionPanel() {
        guard let visibleFrame = visibleFrameProvider() else { return }

        panel.setFrame(
            Self.frame(panelSize: Self.panelSize, in: visibleFrame),
            display: false
        )
    }

    private static func defaultVisibleFrame() -> NSRect? {
        (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
    }
}
