import AppKit
import Foundation
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
                visibleFrameProvider: { nil }
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
                visibleFrameProvider: { nil }
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

    func testVisiblePanelRepositionsAfterScreenParametersChange() async {
        let notificationCenter = NotificationCenter()
        let initiallyPositioned = expectation(description: "panel initially positioned")
        let repositioned = expectation(description: "visible panel repositioned")
        let box = OverlayPanelControllerTestBox()
        let initialVisibleFrame = NSRect(x: 0, y: 0, width: 1_200, height: 800)
        let updatedVisibleFrame = NSRect(x: 400, y: 80, width: 900, height: 700)
        box.visibleFrame = initialVisibleFrame

        await MainActor.run {
            _ = NSApplication.shared
            let viewModel = WheelAppViewModel(fixture: .triggerHeld)
            let controller = WheelGestureOverlayPanelController(
                viewModel: viewModel,
                contentView: NSView(),
                visibleFrameProvider: {
                    box.visibleFrameProviderCallCount += 1
                    if box.visibleFrameProviderCallCount == 1 {
                        initiallyPositioned.fulfill()
                    } else if box.visibleFrameProviderCallCount == 2 {
                        repositioned.fulfill()
                    }
                    return box.visibleFrame
                },
                notificationCenter: notificationCenter
            )
            box.controller = controller
            controller.start()
        }

        await fulfillment(of: [initiallyPositioned], timeout: 1)
        await MainActor.run {
            XCTAssertEqual(
                box.controller?.panel.frame,
                WheelGestureOverlayPanelController.frame(
                    panelSize: WheelGestureOverlayPanelController.panelSize,
                    in: initialVisibleFrame
                )
            )
            box.visibleFrame = updatedVisibleFrame
            notificationCenter.post(
                name: NSApplication.didChangeScreenParametersNotification,
                object: nil
            )
        }

        await fulfillment(of: [repositioned], timeout: 1)
        await MainActor.run {
            XCTAssertEqual(
                box.controller?.panel.frame,
                WheelGestureOverlayPanelController.frame(
                    panelSize: WheelGestureOverlayPanelController.panelSize,
                    in: updatedVisibleFrame
                )
            )
            box.controller?.shutdown()
            box.controller = nil
        }
    }

    func testHiddenOrShutdownPanelIgnoresScreenParametersChange() async {
        let box = OverlayPanelControllerTestBox()
        let notificationCenter = NotificationCenter()
        box.visibleFrame = NSRect(x: 0, y: 0, width: 1_200, height: 800)

        await MainActor.run {
            _ = NSApplication.shared
            let viewModel = WheelAppViewModel(fixture: .ready)
            let controller = WheelGestureOverlayPanelController(
                viewModel: viewModel,
                contentView: NSView(),
                visibleFrameProvider: {
                    box.visibleFrameProviderCallCount += 1
                    return box.visibleFrame
                },
                notificationCenter: notificationCenter
            )
            box.controller = controller
            controller.start()

            notificationCenter.post(
                name: NSApplication.didChangeScreenParametersNotification,
                object: nil
            )
        }

        await drainMainQueue()
        await MainActor.run {
            XCTAssertEqual(box.visibleFrameProviderCallCount, 0)
            box.controller?.apply(.triggerHeld, animated: false)
            XCTAssertEqual(box.visibleFrameProviderCallCount, 1)
            box.controller?.shutdown()
            notificationCenter.post(
                name: NSApplication.didChangeScreenParametersNotification,
                object: nil
            )
        }

        await drainMainQueue()
        await MainActor.run {
            XCTAssertEqual(box.visibleFrameProviderCallCount, 1)
            box.controller = nil
        }
    }

    func testPanelControllerDoesNotReadPointerCoordinates() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(
                "Sources/WheelMacOS/WheelGestureOverlayPanelController.swift"
            )
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("NSEvent.mouseLocation"))
        XCTAssertFalse(source.contains("CGEvent.location"))
    }

    private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }
}

private final class OverlayPanelControllerTestBox: @unchecked Sendable {
    var controller: WheelGestureOverlayPanelController?
    var visibleFrameProviderCallCount = 0
    var visibleFrame: NSRect?
}
