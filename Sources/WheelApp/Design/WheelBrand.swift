import AppKit
import SwiftUI

/// Wheel's identity is separate from semantic macOS content and control colors.
enum WheelBrand {
    static let name = "Wheel"
    static let tagline = "Move through your Mac context instantly."

    static let primaryBackground = Color(red: 11 / 255, green: 20 / 255, blue: 40 / 255)
    static let secondaryBackground = Color(red: 23 / 255, green: 44 / 255, blue: 82 / 255)
    static let cyan = Color(red: 77 / 255, green: 231 / 255, blue: 244 / 255)
    static let electricBlue = Color(red: 37 / 255, green: 140 / 255, blue: 255 / 255)
    static let violet = Color(red: 99 / 255, green: 80 / 255, blue: 238 / 255)
    static let purple = Color(red: 180 / 255, green: 91 / 255, blue: 239 / 255)
    static let primaryForeground = Color.primary
    static let mutedForeground = Color.secondary

    static let gradient = LinearGradient(
        colors: [cyan, electricBlue, violet, purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let colorSymbol = image(named: "WheelSymbol")
    static let lightSymbol = image(named: "WheelSymbolLight")
    static let appIcon = image(named: "WheelAppIcon", extension: "png")

    /// The status item always retains the Radial Context silhouette, in every state.
    static let menuBarTemplateImage: NSImage = {
        let image = WheelBrand.image(named: "WheelMenuBarTemplate") ?? fallbackTemplateImage()
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }()

    /// A packaged app must resolve its own resources, including after relocation.
    /// Do not evaluate SwiftPM's absolute development bundle lookup in that case.
    static func resourceBundle(
        for applicationBundle: Bundle = .main,
        developmentBundle: Bundle? = nil
    ) -> Bundle? {
        if applicationBundle.bundleIdentifier == "dev.gogolumo.Wheel" {
            guard let resources = applicationBundle.resourceURL else { return nil }
            return Bundle(
                url: resources.appendingPathComponent("Wheel_WheelApp.bundle", isDirectory: true)
            )
        }
        return developmentBundle ?? .module
    }

    static func image(named name: String, extension fileExtension: String = "pdf") -> NSImage? {
        guard let url = resourceBundle()?.url(forResource: name, withExtension: fileExtension) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    /// Keeps a damaged resource install recognizable without substituting a generic icon.
    /// The package verifier checks required assets before distribution.
    private static func fallbackTemplateImage() -> NSImage {
        NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.addPath(WheelRadialContextFallback().path(in: rect).cgPath)
            context.setFillColor(NSColor.black.cgColor)
            context.fillPath()
            return true
        }
    }
}
