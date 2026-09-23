import AppKit
import XCTest
@testable import WheelMacOS

final class WheelGestureOverlayPanelControllerTests: XCTestCase {
    func testPanelIsNonactivatingClickThroughAndSpaceAware() async {
        await MainActor.run {
            _ = NSApplication.shared
            let viewModel = WheelAppViewModel(fixture: .ready)
            let controller = WheelGestureOverlayPanelController(
                viewModel: viewModel,
                contentView: NSView(),
                screenProvider: { nil }
            )
            let panel = controller.panel

            XCTAssertTrue(panel.styleMask.contains(.borderless))
            XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
            XCTAssertFalse(panel.canBecomeKey)
            XCTAssertFalse(panel.canBecomeMain)
            XCTAssertTrue(panel.ignoresMouseEvents)
            XCTAssertTrue(panel.isFloatingPanel)
            XCTAssertTrue(panel.isExcludedFromWindowsMenu)
            XCTAssertEqual(panel.level, .statusBar)
            XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
            XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
            XCTAssertTrue(panel.collectionBehavior.contains(.ignoresCycle))

            controller.shutdown()
        }
    }

    func testControllerReusesOnePanelAcrossPresentations() async {
        await MainActor.run {
            _ = NSApplication.shared
            let viewModel = WheelAppViewModel(fixture: .ready)
            let controller = WheelGestureOverlayPanelController(
                viewModel: viewModel,
                contentView: NSView(),
                screenProvider: { nil }
            )
            let originalPanel = controller.panel

            controller.apply(.triggerHeld, animated: false)
            controller.apply(.hidden, animated: false)
            controller.apply(.resultRight, animated: false)

            XCTAssertTrue(originalPanel === controller.panel)
            XCTAssertTrue(controller.panel.isVisible)

            controller.shutdown()
        }
    }

    func testPanelFrameIsCenteredInsideVisibleScreen() async {
        await MainActor.run {
            let visibleFrame = NSRect(x: 100, y: 50, width: 1_200, height: 800)
            let panelSize = NSSize(width: 400, height: 160)

            let frame = WheelGestureOverlayPanelController.frame(
                panelSize: panelSize,
                in: visibleFrame
            )

            XCTAssertEqual(frame.size, panelSize)
            XCTAssertEqual(frame.midX, visibleFrame.midX)
            XCTAssertEqual(frame.midY, visibleFrame.midY)
        }
    }
}
