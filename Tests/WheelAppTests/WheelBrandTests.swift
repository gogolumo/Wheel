import AppKit
import ImageIO
import XCTest
@testable import WheelApp

final class WheelBrandTests: XCTestCase {
    func testProductionBrandResourcesDecode() async throws {
        try await MainActor.run {
            let bundle = try XCTUnwrap(WheelBrand.resourceBundle())
            for name in [
                "WheelSymbol", "WheelSymbolLight", "WheelSymbolMonochromeBlack",
                "WheelSymbolMonochromeWhite", "WheelMenuBarTemplate"
            ] {
                let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "pdf"), name)
                let image = try XCTUnwrap(NSImage(contentsOf: url), name)
                XCTAssertTrue(image.isValid, name)
                XCTAssertGreaterThan(image.size.width, 0, name)
                XCTAssertGreaterThan(image.size.height, 0, name)
                XCTAssertNotNil(WheelBrand.image(named: name), name)
            }

            let iconURL = try XCTUnwrap(bundle.url(forResource: "WheelAppIcon", withExtension: "png"))
            let icon = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: iconURL)))
            XCTAssertEqual(icon.pixelsWide, 1_024)
            XCTAssertEqual(icon.pixelsHigh, 1_024)
            XCTAssertNotNil(WheelBrand.image(named: "WheelAppIcon", extension: "png"))
        }
    }

    func testStatusImageIsAnEighteenPointTemplate() async {
        await MainActor.run {
            let image = WheelBrand.menuBarTemplateImage
            XCTAssertTrue(image.isValid)
            XCTAssertTrue(image.isTemplate)
            XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        }
    }

    func testPackagedApplicationWithoutResourcesRejectsDevelopmentFallback() throws {
        let application = try temporaryApplication()
        defer { try? FileManager.default.removeItem(at: application.root) }
        let development = try XCTUnwrap(WheelBrand.resourceBundle())

        XCTAssertNil(WheelBrand.resourceBundle(
            for: application.bundle,
            developmentBundle: development
        ))
    }

    func testRelocatedApplicationUsesItsOwnResourceBundle() throws {
        let application = try temporaryApplication()
        defer { try? FileManager.default.removeItem(at: application.root) }
        let development = try XCTUnwrap(WheelBrand.resourceBundle())
        let resourcesURL = try XCTUnwrap(application.bundle.resourceURL)
        let packagedURL = resourcesURL.appendingPathComponent("Wheel_WheelApp.bundle", isDirectory: true)
        try FileManager.default.copyItem(at: development.bundleURL, to: packagedURL)

        let resolved = try XCTUnwrap(WheelBrand.resourceBundle(
            for: application.bundle,
            developmentBundle: development
        ))
        XCTAssertEqual(resolved.bundleURL.standardizedFileURL, packagedURL.standardizedFileURL)
        XCTAssertNotEqual(resolved.bundleURL.standardizedFileURL, development.bundleURL.standardizedFileURL)
        for (name, fileExtension) in [
            ("WheelSymbol", "pdf"),
            ("WheelSymbolLight", "pdf"),
            ("WheelMenuBarTemplate", "pdf"),
            ("WheelAppIcon", "png")
        ] {
            let url = try XCTUnwrap(resolved.url(forResource: name, withExtension: fileExtension), name)
            XCTAssertTrue(url.path.hasPrefix(packagedURL.path + "/"), name)
        }
    }

    func testCommittedIconsetHasEveryRequiredNativeResolution() throws {
        let iconset = repositoryRoot.appendingPathComponent("packaging/Wheel.iconset", isDirectory: true)
        let expected: [String: Int] = [
            "icon_16x16.png": 16,
            "icon_16x16@2x.png": 32,
            "icon_32x32.png": 32,
            "icon_32x32@2x.png": 64,
            "icon_128x128.png": 128,
            "icon_128x128@2x.png": 256,
            "icon_256x256.png": 256,
            "icon_256x256@2x.png": 512,
            "icon_512x512.png": 512,
            "icon_512x512@2x.png": 1_024
        ]

        for (filename, size) in expected {
            let url = iconset.appendingPathComponent(filename)
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil), filename)
            XCTAssertEqual(CGImageSourceGetCount(source), 1, filename)
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil), filename)
            XCTAssertEqual(image.width, size, filename)
            XCTAssertEqual(image.height, size, filename)

            let bitmap = NSBitmapImageRep(cgImage: image)
            let center = try XCTUnwrap(bitmap.colorAt(x: size / 2, y: size / 2), filename)
            let corner = try XCTUnwrap(bitmap.colorAt(x: 0, y: 0), filename)
            XCTAssertGreaterThan(center.alphaComponent, 0.9, filename)
            XCTAssertLessThan(corner.alphaComponent, 0.1, filename)
        }
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func temporaryApplication() throws -> (root: URL, bundle: Bundle) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WheelBrandTests-\(UUID().uuidString)", isDirectory: true)
        let app = root.appendingPathComponent("Wheel.app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(
            at: contents.appendingPathComponent("Resources", isDirectory: true),
            withIntermediateDirectories: true
        )
        let info: [String: String] = [
            "CFBundleIdentifier": "dev.gogolumo.Wheel",
            "CFBundleExecutable": "Wheel",
            "CFBundleName": "Wheel",
            "CFBundlePackageType": "APPL"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"), options: .atomic)
        do {
            let bundle = try XCTUnwrap(Bundle(url: app))
            XCTAssertEqual(bundle.bundleIdentifier, "dev.gogolumo.Wheel")
            return (root, bundle)
        } catch {
            try? FileManager.default.removeItem(at: root)
            throw error
        }
    }
}
