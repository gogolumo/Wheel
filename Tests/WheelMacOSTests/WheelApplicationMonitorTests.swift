import AppKit
import XCTest
@testable import WheelMacOS

final class WheelApplicationMonitorTests: XCTestCase {
    func testTerminationNotificationIsDeliveredOnMainThread() async {
        let callbackDelivered = expectation(
            description: "termination callback delivered"
        )
        let processIdentifier = ProcessInfo.processInfo.processIdentifier
        let box = await MainActor.run { WheelApplicationMonitorTestBox() }

        await MainActor.run {
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
            guard let application = NSRunningApplication(
                processIdentifier: processIdentifier
            ) else {
                XCTFail("Could not resolve the XCTest process")
                return
            }
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
        let processIdentifier = ProcessInfo.processInfo.processIdentifier

        await MainActor.run {
            let monitor = WheelApplicationMonitor(
                currentProcessIdentifier: processIdentifier + 1
            )
            monitor.onTerminated = { _ in
                unexpectedCallback.fulfill()
            }
            monitor.start()
            monitor.stop()
            guard let application = NSRunningApplication(
                processIdentifier: processIdentifier
            ) else {
                XCTFail("Could not resolve the XCTest process")
                return
            }
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
