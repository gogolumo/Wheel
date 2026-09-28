import AppKit
import Foundation

public enum WheelApplicationActivationError: Error, Equatable {
    case missingLaunchTarget
    case activationRejected
    case launchFailed(String)
}

extension WheelApplicationActivationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingLaunchTarget:
            return "Wheel no longer knows where this application is installed."
        case .activationRejected:
            return "macOS did not activate the selected application."
        case let .launchFailed(message):
            return "macOS could not launch the selected application: \(message)"
        }
    }
}

@MainActor
public protocol WheelApplicationActivating: AnyObject {
    func activate(
        _ context: WheelApplicationContext,
        completion: @escaping (Result<Void, Error>) -> Void
    )
}

@MainActor
public final class WheelApplicationActivator: WheelApplicationActivating {
    private let workspace: NSWorkspace
    private let fileManager: FileManager

    public init(
        workspace: NSWorkspace = .shared,
        fileManager: FileManager = .default
    ) {
        self.workspace = workspace
        self.fileManager = fileManager
    }

    public func activate(
        _ context: WheelApplicationContext,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        if let bundleIdentifier = context.bundleIdentifier,
           let running = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first(where: { !$0.isTerminated })
        {
            let accepted = running.activate(options: [.activateAllWindows])
            completion(
                accepted
                    ? .success(())
                    : .failure(WheelApplicationActivationError.activationRejected)
            )
            return
        }

        guard let applicationURL = launchURL(for: context) else {
            completion(.failure(WheelApplicationActivationError.missingLaunchTarget))
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false

        workspace.openApplication(
            at: applicationURL,
            configuration: configuration
        ) { application, error in
            DispatchQueue.main.async {
                if let error {
                    completion(
                        .failure(
                            WheelApplicationActivationError.launchFailed(
                                error.localizedDescription
                            )
                        )
                    )
                    return
                }

                guard let application else {
                    completion(
                        .failure(WheelApplicationActivationError.activationRejected)
                    )
                    return
                }

                _ = application.activate(options: [.activateAllWindows])
                completion(.success(()))
            }
        }
    }

    private func launchURL(
        for context: WheelApplicationContext
    ) -> URL? {
        if let applicationURL = context.applicationURL,
           fileManager.fileExists(atPath: applicationURL.path)
        {
            return applicationURL
        }

        if let bundleIdentifier = context.bundleIdentifier,
           let resolved = workspace.urlForApplication(
                withBundleIdentifier: bundleIdentifier
           )
        {
            return resolved
        }

        return nil
    }
}
