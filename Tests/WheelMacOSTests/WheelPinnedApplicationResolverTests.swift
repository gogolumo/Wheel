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

    func testRejectsNestedHelperApplicationPath() async {
        let helperURL = URL(
            fileURLWithPath:
                "/Applications/Example.app/Contents/Helpers/Example Helper.app"
        )

        let result = await MainActor.run {
            Result {
                try WheelPinnedApplicationResolver().pinnedApplication(
                    from: helperURL
                )
            }
        }

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(
                error as? WheelPinnedApplicationResolutionError,
                .notApplicationBundle
            )
        }
    }

    func testResolveUsesMatchingStoredApplicationBundle() async throws {
        let bundleIdentifier = "dev.gogolumo.matching-\(UUID().uuidString)"
        let applicationURL = try makeApplicationBundle(
            name: "Matching App",
            bundleIdentifier: bundleIdentifier
        )
        defer { try? FileManager.default.removeItem(at: applicationURL) }

        let context = await MainActor.run {
            WheelPinnedApplicationResolver().resolve(
                WheelPinnedApplication(
                    stableIdentifier: "bundle:\(bundleIdentifier)",
                    localizedName: "Matching App",
                    bundleIdentifier: bundleIdentifier,
                    applicationURL: applicationURL
                ),
                liveContexts: []
            )
        }

        XCTAssertEqual(context.runState, .terminated)
        XCTAssertEqual(
            context.applicationURL,
            applicationURL.standardizedFileURL
        )
    }

    func testResolveRejectsStoredPathWithDifferentBundleIdentifier() async throws {
        let originalIdentifier = "dev.gogolumo.original-\(UUID().uuidString)"
        let replacementURL = try makeApplicationBundle(
            name: "Replacement App",
            bundleIdentifier: "dev.gogolumo.replacement-\(UUID().uuidString)"
        )
        defer { try? FileManager.default.removeItem(at: replacementURL) }

        let context = await MainActor.run {
            WheelPinnedApplicationResolver().resolve(
                WheelPinnedApplication(
                    stableIdentifier: "bundle:\(originalIdentifier)",
                    localizedName: "Original App",
                    bundleIdentifier: originalIdentifier,
                    applicationURL: replacementURL
                ),
                liveContexts: []
            )
        }

        XCTAssertEqual(context.runState, .unavailable)
        XCTAssertNil(context.applicationURL)
    }

    func testResolveRejectsMalformedStoredApplicationBundle() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let malformedURL = root.appendingPathComponent(
            "Malformed.app",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: malformedURL,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let context = await MainActor.run {
            WheelPinnedApplicationResolver().resolve(
                WheelPinnedApplication(
                    stableIdentifier: "url:\(malformedURL.path)",
                    localizedName: "Malformed",
                    bundleIdentifier: nil,
                    applicationURL: malformedURL
                ),
                liveContexts: []
            )
        }

        XCTAssertEqual(context.runState, .unavailable)
        XCTAssertNil(context.applicationURL)
    }

    private func makeApplicationBundle(
        name: String,
        bundleIdentifier: String
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

        let info: [String: Any] = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleName": name,
            "CFBundleDisplayName": name,
            "CFBundlePackageType": "APPL",
            "CFBundleExecutable": "TestExecutable"
        ]
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
