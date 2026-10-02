import AppKit
import QuartzCore
import SwiftUI
import WheelMacOS

/// Explicit, offscreen production-view exports with isolated synthetic fixtures.
/// This renders new, never-shown fixture windows; it never captures a screen or another window.
@MainActor
enum WheelSettingsFixtureRenderer {
    static func render(to directory: URL) throws -> Int {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var count = 0

        for dark in [false, true] {
            let appearance = dark ? "dark" : "light"
            for section in WheelDashboardView.Section.allCases {
                let viewModel = WheelAppViewModel(visualFixture: .mixedPins)
                // Native NavigationSplitView chrome is not faithfully drawn by
                // cacheDisplay while hidden. Export the actual detail component
                // instead; sidebar and window chrome remain physical QA items.
                let content = settingsContent(section: section, viewModel: viewModel)
                    .frame(width: 860, height: 640)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .environment(\.colorScheme, dark ? .dark : .light)
                let host = NSHostingView(rootView: content)
                let window = fixtureWindow(host, dark: dark, size: NSSize(width: 860, height: 640))
                defer { window.close() }
                let identifier = section.rawValue.lowercased().replacingOccurrences(of: " ", with: "-")
                try export(
                    host,
                    to: directory.appendingPathComponent("settings-\(identifier)-content-\(appearance).png")
                )
                count += 1
            }

            for fixture in WheelAppFixture.allCases {
                let viewModel = WheelAppViewModel(fixture: fixture)
                try exportMenu(
                    viewModel: viewModel,
                    dark: dark,
                    to: directory.appendingPathComponent("menu-\(fixture.rawValue)-opaque-fallback-\(appearance).png")
                )
                count += 1
            }

            // Legacy status fixtures have no application history. This additional
            // synthetic fixture verifies the real recent-application row's layout.
            try exportMenu(
                viewModel: WheelAppViewModel(visualFixture: .mixedPins),
                dark: dark,
                to: directory.appendingPathComponent("menu-recent-application-opaque-fallback-\(appearance).png")
            )
            count += 1
        }

        return count
    }

    @ViewBuilder
    private static func settingsContent(
        section: WheelDashboardView.Section,
        viewModel: WheelAppViewModel
    ) -> some View {
        switch section {
        case .general: WheelGeneralSettingsView(viewModel: viewModel)
        case .layout: WheelLayoutSettingsView(viewModel: viewModel)
        case .applications: WheelApplicationsSettingsView(viewModel: viewModel)
        case .history: WheelHistorySettingsView(viewModel: viewModel)
        case .appearance: WheelAppearanceSettingsView()
        case .permissions: WheelPermissionsSettingsView(viewModel: viewModel)
        case .advanced: WheelAdvancedSettingsView(viewModel: viewModel)
        case .about: WheelAboutSettingsView()
        }
    }

    private static func exportMenu(
        viewModel: WheelAppViewModel,
        dark: Bool,
        to destination: URL
    ) throws {
        let content = WheelMenuBarView(viewModel: viewModel)
            .environment(\.colorScheme, dark ? .dark : .light)
            // Native glass shaders cannot provide a reliable offscreen bitmap.
            // This additive fixture policy exercises the real opaque fallback;
            // it never turns off an existing system accessibility preference.
            .environment(\.wheelAccessibilityReview, WheelAccessibilityReview(reduceTransparency: true))
        let host = NSHostingView(rootView: content)
        let window = fixtureWindow(host, dark: dark, size: NSSize(width: 300, height: 550))
        defer { window.close() }
        let fittingHeight = host.fittingSize.height.rounded(.up)
        guard fittingHeight.isFinite, fittingHeight > 0, fittingHeight <= 550 else {
            throw RenderError.invalidMenuHeight
        }
        window.setContentSize(NSSize(width: 300, height: fittingHeight))
        settle(host)
        try export(host, to: destination)
    }

    private static func fixtureWindow<Content: View>(
        _ host: NSHostingView<Content>,
        dark: Bool,
        size: NSSize
    ) -> NSWindow {
        // A window context is required by the native split view / table view.
        // It is never ordered on screen, made key, or activated.
        let window = WheelOffscreenFixtureWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        host.appearance = window.appearance
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]
        window.contentView = host
        window.layoutIfNeeded()
        settle(host)
        return window
    }

    private static func settle(_ host: NSView) {
        host.needsLayout = true
        host.layoutSubtreeIfNeeded()
        // Let SwiftUI finish the native hosting/table layout transaction. Only
        // isolated fixtures are active; no production input runtime is started.
        CATransaction.flush()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        CATransaction.flush()
    }

    private static func export(_ host: NSView, to destination: URL) throws {
        guard let window = host.window,
              !window.isVisible, !window.isKeyWindow, !window.isMainWindow
        else {
            throw RenderError.windowVisibility
        }
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw RenderError.bitmapUnavailable
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw RenderError.bitmapUnavailable
        }
        try png.write(to: destination, options: .atomic)
    }

    private enum RenderError: LocalizedError {
        case invalidMenuHeight, bitmapUnavailable, windowVisibility

        var errorDescription: String? {
            switch self {
            case .invalidMenuHeight:
                return "The compact menu fixture did not fit within its 550 pt review limit."
            case .bitmapUnavailable:
                return "The offscreen Settings or menu fixture could not produce a PNG."
            case .windowVisibility:
                return "Fixture export requires a hidden, non-key fixture window."
            }
        }
    }
}

private final class WheelOffscreenFixtureWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
