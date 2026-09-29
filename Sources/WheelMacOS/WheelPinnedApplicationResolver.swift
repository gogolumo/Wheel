import AppKit
import Foundation

public enum WheelPinnedApplicationResolutionError: Error, Equatable {
    case notApplicationBundle
    case unsupportedBundleType
    case systemUtility
}

extension WheelPinnedApplicationResolutionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notApplicationBundle:
            return "Choose a macOS application (.app)."
        case .unsupportedBundleType:
            return "Wheel can only pin normal application bundles."
        case .systemUtility:
            return "That system utility is not a user-facing application Wheel can pin."
        }
    }
}

/// Resolves a persisted pin back to an installed app without making its old path
/// the source of truth. Bundle identifier wins; the stored URL is a fallback.
@MainActor
public final class WheelPinnedApplicationResolver {
    private let workspace: NSWorkspace
    private let fileManager: FileManager

    public init(
        workspace: NSWorkspace = .shared,
        fileManager: FileManager = .default
    ) {
        self.workspace = workspace
        self.fileManager = fileManager
    }

    public func pinnedApplication(
        from applicationURL: URL
    ) throws -> WheelPinnedApplication {
        let url = applicationURL.standardizedFileURL
        let lowercasedPath = url.path.lowercased()

        guard url.pathExtension.lowercased() == "app",
              !lowercasedPath.contains(".app/contents/")
        else {
            throw WheelPinnedApplicationResolutionError.notApplicationBundle
        }

        guard let bundle = Bundle(url: url) else {
            throw WheelPinnedApplicationResolutionError.notApplicationBundle
        }

        if let packageType = bundle.object(
            forInfoDictionaryKey: "CFBundlePackageType"
        ) as? String,
           packageType != "APPL"
        {
            throw WheelPinnedApplicationResolutionError.unsupportedBundleType
        }

        if bundle.object(forInfoDictionaryKey: "LSUIElement") as? Bool == true
            || bundle.object(forInfoDictionaryKey: "LSBackgroundOnly") as? Bool == true
        {
            throw WheelPinnedApplicationResolutionError.unsupportedBundleType
        }

        let bundleIdentifier = bundle.bundleIdentifier
        if bundleIdentifier == "com.apple.loginwindow"
            || bundleIdentifier == "com.apple.SecurityAgent"
        {
            throw WheelPinnedApplicationResolutionError.systemUtility
        }

        let displayName = (
            bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        )
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent

        let stableIdentifier: String
        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            stableIdentifier = "bundle:\(bundleIdentifier)"
        } else {
            stableIdentifier = "url:\(url.path)"
        }

        return WheelPinnedApplication(
            stableIdentifier: stableIdentifier,
            localizedName: displayName,
            bundleIdentifier: bundleIdentifier,
            applicationURL: url
        )
    }

    public func resolve(
        _ pinned: WheelPinnedApplication,
        liveContexts: [WheelApplicationContext]
    ) -> WheelApplicationContext {
        if let live = liveContexts.first(where: {
            $0.stableIdentifier == pinned.stableIdentifier
                || (
                    pinned.bundleIdentifier != nil
                        && $0.bundleIdentifier == pinned.bundleIdentifier
                )
        }) {
            return live
        }

        if let bundleIdentifier = pinned.bundleIdentifier,
           let running = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first(where: { !$0.isTerminated })
        {
            let runningURL = running.bundleURL ?? installedURL(for: pinned)
            return WheelApplicationContext(
                stableIdentifier: pinned.stableIdentifier,
                localizedName: running.localizedName ?? pinned.localizedName,
                bundleIdentifier: bundleIdentifier,
                applicationURL: runningURL,
                firstSeenAt: .distantPast,
                lastActivatedAt: .distantPast,
                runState: .running
            )
        }

        let resolvedURL = installedURL(for: pinned)

        return WheelApplicationContext(
            stableIdentifier: pinned.stableIdentifier,
            localizedName: pinned.localizedName,
            bundleIdentifier: pinned.bundleIdentifier,
            applicationURL: resolvedURL,
            firstSeenAt: .distantPast,
            lastActivatedAt: .distantPast,
            runState: resolvedURL == nil ? .unavailable : .terminated
        )
    }

    private func installedURL(
        for pinned: WheelPinnedApplication
    ) -> URL? {
        if let bundleIdentifier = pinned.bundleIdentifier,
           let resolved = workspace.urlForApplication(
               withBundleIdentifier: bundleIdentifier
           ),
           isValidApplicationURL(
               resolved,
               expectedBundleIdentifier: bundleIdentifier
           )
        {
            return resolved.standardizedFileURL
        }

        if let storedURL = pinned.applicationURL,
           isValidApplicationURL(
               storedURL,
               expectedBundleIdentifier: pinned.bundleIdentifier
           )
        {
            return storedURL.standardizedFileURL
        }

        return nil
    }

    /// A persisted path is only a hint. It must still identify the same normal
    /// application bundle before Wheel exposes it as a launch target.
    private func isValidApplicationURL(
        _ applicationURL: URL,
        expectedBundleIdentifier: String?
    ) -> Bool {
        let url = applicationURL.standardizedFileURL
        let lowercasedPath = url.path.lowercased()

        guard url.pathExtension.lowercased() == "app",
              !lowercasedPath.contains(".app/contents/"),
              fileManager.fileExists(atPath: url.path),
              let bundle = Bundle(url: url)
        else {
            return false
        }

        if let packageType = bundle.object(
            forInfoDictionaryKey: "CFBundlePackageType"
        ) as? String,
           packageType != "APPL"
        {
            return false
        }

        if bundle.object(forInfoDictionaryKey: "LSUIElement") as? Bool == true
            || bundle.object(forInfoDictionaryKey: "LSBackgroundOnly") as? Bool == true
        {
            return false
        }

        if let expectedBundleIdentifier,
           bundle.bundleIdentifier != expectedBundleIdentifier
        {
            return false
        }

        return bundle.bundleIdentifier != "com.apple.loginwindow"
            && bundle.bundleIdentifier != "com.apple.SecurityAgent"
    }
}
