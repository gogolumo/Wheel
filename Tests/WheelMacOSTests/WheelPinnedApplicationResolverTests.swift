import Foundation
import XCTest
@testable import WheelMacOS

final class WheelPinnedApplicationResolverTests: XCTestCase {
    func testCreatesPinFromNormalApplicationBundle() async throws {
        let applicationURL = try makeApplicationBundle(
            name: "Test Browser",
            bundleIdentifier: "dev.gogolumo.test-browser"
        )
        defer { try? FileManager.default.removeItem(at: applicationURL) }

        let pinned = try await MainActor.run {
            try WheelPinnedApplicationResolver().pinnedApplication(
                from: applicationURL
            )
        }

        XCTAssertEqual(pinned.localizedName, "Test Browser")
        XCTAssertEqual(
            pinned.bundleIdentifier,
            "dev.gogolumo.test-browser"
        )
        XCTAssertEqual(
            pinned.stableIdentifier,
            "bundle:dev.gogolumo.test-browser"
        )
        XCTAssertEqual(pinned.applicationURL, applicationURL.standardizedFileURL)
    }

    func testRejectsBackgroundOnlyApplicationBundle() async throws {
        let applicationURL = try makeApplicationBundle(
            name: "Background Helper",
            bundleIdentifier: "dev.gogolumo.background-helper",
            extraInfo: ["LSUIElement": true]
        )
        defer { try? FileManager.default.removeItem(
            at: applicationURL.deletingLastPathComponent()
        ) }

        await MainActor.run {
            XCTAssertThrowsError(
                try WheelPinnedApplicationResolver().pinnedApplication(
                    from: applicationURL
                )
            ) { error in
                XCTAssertEqual(
                    error as? WheelPinnedApplicationResolutionError,
                    .unsupportedBundleType
                )
            }
        }
    }

    func testRejectsNestedHelperApplicationPath() async {
        let helperURL = URL(
            fileURLWithPath:
                "/Applications/Example.app/Contents/Helpers/Example Helper.app"
        )

        await MainActor.run {
            XCTAssertThrowsError(
                try WheelPinnedApplicationResolver().pinnedApplication(
                    from: helperURL
                )
            ) { error in
                XCTAssertEqual(
                    error as? WheelPinnedApplicationResolutionError,
                    .notApplicationBundle
                )
            }
        }
    }

    private func makeApplicationBundle(
        name: String,
        bundleIdentifier: String,
        extraInfo: [String: Any] = [:]
    ) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appURL = root.appendingPathComponent(
            "\(name).app",
            isDirectory: true
        )
        let contentsURL = appURL.appendingPathComponent(
            "Contents",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: contentsURL,
            withIntermediateDirectories: true
        )

        var info: [String: Any] = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleName": name,
            "CFBundleDisplayName": name,
            "CFBundlePackageType": "APPL",
            "CFBundleExecutable": "TestExecutable"
        ]
        info.merge(extraInfo) { _, new in new }
        let data = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try data.write(
            to: contentsURL.appendingPathComponent("Info.plist")
        )

        return appURL
    }
}
