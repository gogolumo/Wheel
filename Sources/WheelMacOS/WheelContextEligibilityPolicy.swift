import AppKit
import Foundation

/// Central positive-eligibility policy for contexts that are useful to a person.
/// Wheel records user-facing applications, not every process macOS happens to launch.
public struct WheelContextEligibilityPolicy: Sendable {
    public init() {}

    public func allows(
        activationPolicy: NSApplication.ActivationPolicy,
        bundleIdentifier: String?,
        applicationURL: URL?,
        localizedName: String,
        isTerminated: Bool
    ) -> Bool {
        guard !isTerminated else { return false }
        guard activationPolicy == .regular else { return false }
        guard bundleIdentifier != "com.apple.loginwindow" else { return false }
        guard bundleIdentifier != "com.apple.SecurityAgent" else { return false }
        guard applicationURL != nil || bundleIdentifier != nil else { return false }
        guard !localizedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return true
    }

    public func allows(_ application: NSRunningApplication) -> Bool {
        let name = application.localizedName
            ?? application.bundleURL?.deletingPathExtension().lastPathComponent
            ?? application.bundleIdentifier
            ?? ""
        return allows(
            activationPolicy: application.activationPolicy,
            bundleIdentifier: application.bundleIdentifier,
            applicationURL: application.bundleURL,
            localizedName: name,
            isTerminated: application.isTerminated
        )
    }
}
