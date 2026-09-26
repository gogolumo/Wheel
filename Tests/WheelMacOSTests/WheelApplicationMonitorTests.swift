import AppKit
import XCTest
@testable import WheelMacOS

final class WheelApplicationMonitorTests: XCTestCase {
    func testTerminationNotificationIsDeliveredOnMainThread() async {
        let callbackDelivered = expectation(
            description: "termination callback delivered"
        )
        let box = await MainActor.run { WheelApplicationMonitorTestBox() }

        await MainActor.run {
            guard let application = NSWorkspace.shared.runningApplications.first else {
                XCTFail("Could not resolve a running application")
                return
            }
            let processIdentifier = application.processIdentifier
            let monitor = WheelApplicationMonitor(
                currentProcessIdentifier: processIdentifier + 1
            )
            monitor.onTerminated = { observation in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(
                    observation.processIdentifier,
                    processIdentifier
                )
                callbackDelivered.fulfill()
            }
            box.monitor = monitor
            monitor.start()
            NSWorkspace.shared.notificationCenter.post(
                name: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                userInfo: [
                    NSWorkspace.applicationUserInfoKey: application
                ]
            )
        }

        await fulfillment(of: [callbackDelivered], timeout: 2)
        await MainActor.run {
            box.monitor?.stop()
            box.monitor = nil
        }
    }

    func testStopRemovesWorkspaceObservers() async {
        let unexpectedCallback = expectation(
            description: "stopped monitor stays silent"
        )
        unexpectedCallback.isInverted = true

        await MainActor.run {
            guard let application = NSWorkspace.shared.runningApplications.first else {
                XCTFail("Could not resolve a running application")
                return
            }
            let monitor = WheelApplicationMonitor(
                currentProcessIdentifier: application.processIdentifier + 1
            )
            monitor.onTerminated = { _ in
                unexpectedCallback.fulfill()
            }
            monitor.start()
            monitor.stop()
            NSWorkspace.shared.notificationCenter.post(
                name: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                userInfo: [
                    NSWorkspace.applicationUserInfoKey: application
                ]
            )
        }

        await fulfillment(of: [unexpectedCallback], timeout: 0.2)
    }
}

@MainActor
private final class WheelApplicationMonitorTestBox {
    var monitor: WheelApplicationMonitor?
}
