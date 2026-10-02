import AppKit
import QuartzCore
import SwiftUI
import XCTest
@testable import WheelApp
import WheelMacOS

final class WheelSettingsLayoutTests: XCTestCase {
    func testApplicationsFitDefaultWindowInsteadOfUsingFullFormHeight() async {
        await MainActor.run {
            withDashboard(section: .applications, fixture: .mixedPins) { host, window in
                assertSplitFits(host)
                XCTAssertFalse(window.isVisible)
                XCTAssertFalse(window.isKeyWindow)
            }
        }
    }

    func testAllSectionsStayInsideViewportAfterResizing() async {
        await MainActor.run {
            for section in WheelDashboardView.Section.allCases {
                withDashboard(section: section, fixture: .twelve) { host, window in
                    for size in [
                        NSSize(width: 760, height: 592),
                        NSSize(width: 1_000, height: 760),
                        NSSize(width: 860, height: 640)
                    ] {
                        window.setContentSize(size)
                        settle(host)
                        assertSplitFits(host, section: section.rawValue)
                    }
                }
            }
        }
    }

    func testTwelveApplicationSlotsScrollWithinWindow() async {
        await MainActor.run {
            withDashboard(section: .applications, fixture: .twelve) { host, window in
                window.setContentSize(NSSize(width: 760, height: 592))
                settle(host)
                assertSplitFits(host)

                let form = descendants(of: host, matching: NSScrollView.self).first {
                    ($0.documentView?.bounds.height ?? 0) > $0.contentView.bounds.height + 100
                }
                guard let form, let document = form.documentView else {
                    XCTFail("Long application assignments must have a scrollable form")
                    return
                }

                let viewport = form.convert(form.bounds, to: host)
                XCTAssertGreaterThanOrEqual(viewport.minY, host.bounds.minY - 1)
                XCTAssertLessThanOrEqual(viewport.maxY, host.bounds.maxY + 1)
                XCTAssertLessThan(viewport.height, host.bounds.height)

                let bottom = document.bounds.maxY - form.contentView.bounds.height
                form.contentView.scroll(to: NSPoint(x: 0, y: bottom))
                form.reflectScrolledClipView(form.contentView)
                XCTAssertEqual(form.contentView.bounds.maxY, document.bounds.maxY, accuracy: 1)
            }
        }
    }

    @MainActor
    private func withDashboard(
        section: WheelDashboardView.Section,
        fixture: WheelVisualFixture,
        inspect: (NSHostingView<WheelDashboardView>, NSWindow) -> Void
    ) {
        _ = NSApplication.shared
        let host = NSHostingView(rootView: WheelDashboardView(
            viewModel: WheelAppViewModel(visualFixture: fixture),
            initialSection: section
        ))
        let size = NSSize(width: 860, height: 640)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "Wheel Settings"
        window.toolbar = NSToolbar(identifier: "WheelSettingsLayoutTests")
        window.titlebarAppearsTransparent = true
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]
        window.contentView = host
        defer { window.close() }
        settle(host)
        inspect(host, window)
    }

    @MainActor
    private func assertSplitFits(_ host: NSView, section: String = "Applications") {
        guard let split = descendants(of: host, matching: NSSplitView.self).first else {
            XCTFail("\(section) did not create its native split view")
            return
        }
        let frame = split.convert(split.bounds, to: host)
        XCTAssertGreaterThanOrEqual(frame.minY, host.bounds.minY - 1, section)
        XCTAssertLessThanOrEqual(frame.maxY, host.bounds.maxY + 1, section)
        XCTAssertGreaterThan(frame.height, 0, section)
        XCTAssertLessThanOrEqual(frame.height, host.bounds.height + 1, section)
    }

    @MainActor
    private func descendants<T: NSView>(of view: NSView, matching type: T.Type) -> [T] {
        view.subviews.flatMap { child in
            ((child as? T).map { [$0] } ?? [])
                + descendants(of: child, matching: type)
        }
    }

    @MainActor
    private func settle(_ host: NSView) {
        host.window?.layoutIfNeeded()
        host.layoutSubtreeIfNeeded()
        CATransaction.flush()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        host.layoutSubtreeIfNeeded()
    }
}
