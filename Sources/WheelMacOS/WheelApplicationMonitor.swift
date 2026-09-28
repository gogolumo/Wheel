import AppKit
import Foundation

@MainActor
public protocol WheelApplicationMonitoring: AnyObject {
    var onActivated: ((WheelObservedApplication) -> Void)? { get set }
    var onLaunched: ((WheelObservedApplication) -> Void)? { get set }
    var onTerminated: ((WheelObservedApplication) -> Void)? { get set }

    func start()
    func stop()
}

@MainActor
public final class WheelApplicationMonitor: WheelApplicationMonitoring {
    public var onActivated: ((WheelObservedApplication) -> Void)?
    public var onLaunched: ((WheelObservedApplication) -> Void)?
    public var onTerminated: ((WheelObservedApplication) -> Void)?

    private let workspace: NSWorkspace
    private let notificationCenter: NotificationCenter
    private let currentProcessIdentifier: pid_t
    private let eligibilityPolicy: WheelContextEligibilityPolicy
    private var observers: [NSObjectProtocol] = []
    private var isStarted = false

    public init(
        workspace: NSWorkspace = .shared,
        currentProcessIdentifier: pid_t = ProcessInfo.processInfo.processIdentifier,
        eligibilityPolicy: WheelContextEligibilityPolicy = .init()
    ) {
        self.workspace = workspace
        notificationCenter = workspace.notificationCenter
        self.currentProcessIdentifier = currentProcessIdentifier
        self.eligibilityPolicy = eligibilityPolicy
    }

    public func start() {
        guard !isStarted else { return }
        isStarted = true

        // NotificationCenter invokes each block on OperationQueue.main. The
        // synchronous queue guarantee is what makes assumeIsolated safe below.
        observers.append(notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handleActivated(notification)
            }
        })

        observers.append(notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handleLaunched(notification)
            }
        })

        // Termination is intentionally allowed for applications that were useful contexts.
        // The history store uses this event to keep a restorable closed-app entry.
        observers.append(notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handleTerminated(notification)
            }
        })

        if let application = workspace.frontmostApplication,
           let observation = observation(from: application) {
            onActivated?(observation)
        }
    }

    public func stop() {
        guard isStarted else { return }
        isStarted = false
        observers.forEach(notificationCenter.removeObserver)
        observers.removeAll()
    }

    private func handleActivated(_ notification: Notification) {
        guard let observation = observation(from: notification) else { return }
        onActivated?(observation)
    }

    private func handleLaunched(_ notification: Notification) {
        guard let observation = observation(from: notification) else { return }
        onLaunched?(observation)
    }

    private func handleTerminated(_ notification: Notification) {
        guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication,
              application.processIdentifier != currentProcessIdentifier
        else { return }

        let name = application.localizedName
            ?? application.bundleURL?.deletingPathExtension().lastPathComponent
            ?? application.bundleIdentifier
            ?? "Unknown Application"
        onTerminated?(WheelObservedApplication(
            localizedName: name,
            bundleIdentifier: application.bundleIdentifier,
            applicationURL: application.bundleURL,
            processIdentifier: application.processIdentifier
        ))
    }

    private func observation(from notification: Notification) -> WheelObservedApplication? {
        guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return nil
        }
        return observation(from: application)
    }

    private func observation(from application: NSRunningApplication) -> WheelObservedApplication? {
        guard application.processIdentifier != currentProcessIdentifier,
              eligibilityPolicy.allows(application)
        else { return nil }

        let name = application.localizedName
            ?? application.bundleURL?.deletingPathExtension().lastPathComponent
            ?? application.bundleIdentifier
            ?? "Unknown Application"

        return WheelObservedApplication(
            localizedName: name,
            bundleIdentifier: application.bundleIdentifier,
            applicationURL: application.bundleURL,
            processIdentifier: application.processIdentifier
        )
    }
}
