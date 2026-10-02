import AppKit
import SwiftUI
import WheelMacOS

/// Opt-in exports of the production view tree with isolated, synthetic data.
/// Never captures a display, window, wallpaper, or user application content.
@MainActor
enum WheelFixtureRenderer {
    static func isRequested(_ arguments: [String]) -> Bool {
        arguments.contains("--render-fixtures")
    }

    static func render(from arguments: [String]) throws {
        guard let index = arguments.firstIndex(of: "--render-fixtures"),
              arguments.indices.contains(index + 1),
              !arguments[index + 1].hasPrefix("--")
        else {
            throw RenderError.missingDirectory
        }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var exportedCount = 0

        for dark in [false, true] {
            let appearance = dark ? "dark" : "light"
            for fixture in WheelVisualFixture.allCases {
                try export(
                    fixture: fixture, dark: dark,
                    to: directory.appendingPathComponent("\(fixture.rawValue)-\(appearance).png")
                )
                exportedCount += 1
            }
            for mode in ReviewMode.allCases where mode != .standard {
                try export(
                    fixture: .selectedRunning, dark: dark, mode: mode,
                    to: directory.appendingPathComponent("\(mode.rawValue)-\(appearance).png")
                )
                exportedCount += 1
            }
            for backdrop in Backdrop.allCases {
                try export(
                    fixture: .mixedPins, dark: dark, backdrop: backdrop,
                    to: directory.appendingPathComponent("backdrop-\(backdrop.rawValue)-\(appearance).png")
                )
                exportedCount += 1
            }
        }
        exportedCount += try WheelSettingsFixtureRenderer.render(to: directory)
        try """
        Wheel production component fixture exports: \(exportedCount) PNGs.
        Every application identity and background is synthetic.
        Rendered from synthetic NSHostingView trees; Settings content/menu use never-shown non-key windows.
        Settings exports contain actual detail components; native sidebar/chrome require physical review.
        Menu popover snapshots use the opaque fallback because native glass can corrupt offscreen.
        Status label snapshots render the actual monochrome template in Light and Dark appearance.
        No screen/window capture, desktop inspection, or permission request.
        Bitmaps validate layout, typography, state, and explicit accessibility fallbacks.
        Offscreen Material / native Liquid Glass can flatten; live desktop vibrancy, focus,
        global gestures, full screen, and multi-display behavior require physical checks.
        See docs/LIQUID_GLASS_QA.md.
        """.write(to: directory.appendingPathComponent("README.txt"), atomically: true, encoding: .utf8)
        print("Exported \(exportedCount) synthetic Wheel fixture images to \(directory.path)")
    }

    private static func export(
        fixture: WheelVisualFixture,
        dark: Bool,
        mode: ReviewMode = .standard,
        backdrop: Backdrop = .plain,
        to destination: URL
    ) throws {
        let viewModel = WheelAppViewModel(visualFixture: fixture)
        let content = WheelFixtureCanvas(viewModel: viewModel, backdrop: backdrop)
            .environment(\.colorScheme, dark ? .dark : .light)
            .environment(\.wheelAccessibilityReview, WheelAccessibilityReview(
                reduceMotion: mode == .reduceMotion,
                reduceTransparency: mode == .reduceTransparency,
                differentiateWithoutColor: mode == .differentiate,
                increaseContrast: mode == .increaseContrast
            ))
        let host = NSHostingView(rootView: content)
        host.frame = NSRect(x: 0, y: 0, width: 860, height: 560)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw RenderError.bitmapUnavailable
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw RenderError.bitmapUnavailable
        }
        try png.write(to: destination, options: .atomic)
    }

    private enum ReviewMode: String, CaseIterable {
        case standard
        case reduceMotion = "reduce-motion"
        case reduceTransparency = "reduce-transparency"
        case increaseContrast = "increase-contrast"
        case differentiate = "differentiate-without-color"
    }

    fileprivate enum Backdrop: String, CaseIterable {
        case bright, dark, busy, plain

        var colors: [Color] {
            switch self {
            case .bright: return [Color(red: 0.94, green: 0.92, blue: 0.84), Color(red: 0.68, green: 0.81, blue: 0.88)]
            case .dark: return [Color(red: 0.10, green: 0.16, blue: 0.24), Color(red: 0.20, green: 0.24, blue: 0.32)]
            case .busy: return [.blue.opacity(0.6), .orange.opacity(0.4), .indigo.opacity(0.7)]
            case .plain: return [Color(red: 0.42, green: 0.51, blue: 0.63), Color(red: 0.54, green: 0.60, blue: 0.68)]
            }
        }
    }

    private enum RenderError: LocalizedError {
        case missingDirectory, bitmapUnavailable

        var errorDescription: String? {
            switch self {
            case .missingDirectory: return "Usage: wheel-app --render-fixtures <output-directory>"
            case .bitmapUnavailable: return "The offscreen fixture view could not produce a PNG."
            }
        }
    }
}

private struct WheelFixtureCanvas: View {
    @ObservedObject var viewModel: WheelAppViewModel
    let backdrop: WheelFixtureRenderer.Backdrop

    var body: some View {
        ZStack {
            LinearGradient(colors: backdrop.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            if backdrop == .busy {
                // Static synthetic pattern, not a sampled wallpaper.
                Canvas { context, size in
                    for index in 0..<18 {
                        let x = CGFloat(index) * size.width / 18
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x + 220, y: size.height))
                        context.stroke(path, with: .color(.primary.opacity(0.15)), lineWidth: 18)
                    }
                }
            }
            WheelGestureOverlayView(viewModel: viewModel)
                .frame(width: 820, height: 520)
        }
        .frame(width: 860, height: 560)
    }
}
