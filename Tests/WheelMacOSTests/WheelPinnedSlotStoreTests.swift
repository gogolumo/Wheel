import AppKit
import XCTest
@testable import WheelMacOS

final class WheelPinnedSlotStoreTests: XCTestCase {
    func testPinPersistsAndRestores() async {
        await MainActor.run {
            let suite = "WheelPinnedSlotStoreTests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }

            let app = WheelPinnedApplication(
                stableIdentifier: "bundle:net.whatsapp.WhatsApp",
                localizedName: "WhatsApp",
                bundleIdentifier: "net.whatsapp.WhatsApp",
                applicationURL: URL(fileURLWithPath: "/Applications/WhatsApp.app")
            )
            WheelPinnedSlotStore(defaults: defaults).pin(app, at: 0)
            XCTAssertEqual(
                WheelPinnedSlotStore(defaults: defaults).application(at: 0),
                app
            )
        }
    }

    func testReducingDirectionCountDoesNotDeleteHiddenPins() async {
        await MainActor.run {
            let suite = "WheelPinnedSlotStoreTests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let store = WheelPinnedSlotStore(defaults: defaults)
            let app = WheelPinnedApplication(
                stableIdentifier: "bundle:test",
                localizedName: "Test",
                bundleIdentifier: "test",
                applicationURL: URL(fileURLWithPath: "/Applications/Test.app")
            )
            store.pin(app, at: 7)
            XCTAssertTrue(store.visibleSlots(directionCount: 4).isEmpty)
            XCTAssertEqual(store.visibleSlots(directionCount: 8).count, 1)
        }
    }

    func testPinnedApplicationIsNotDuplicatedInDynamicSlots() async {
        await MainActor.run {
            let suite = "WheelPinnedSlotStoreTests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let store = WheelPinnedSlotStore(defaults: defaults)
            let now = Date()
            let whatsapp = WheelApplicationContext(
                stableIdentifier: "bundle:whatsapp",
                localizedName: "WhatsApp",
                bundleIdentifier: "whatsapp",
                applicationURL: URL(
                    fileURLWithPath: "/Applications/WhatsApp.app"
                ),
                firstSeenAt: now,
                lastActivatedAt: now,
                runState: .running
            )
            let safari = WheelApplicationContext(
                stableIdentifier: "bundle:safari",
                localizedName: "Safari",
                bundleIdentifier: "safari",
                applicationURL: URL(
                    fileURLWithPath: "/Applications/Safari.app"
                ),
                firstSeenAt: now,
                lastActivatedAt: now,
                runState: .running
            )
            store.pin(.init(context: whatsapp), at: 0)
            let merged = store.merge(
                dynamic: [whatsapp, safari],
                directionCount: 4
            ).compactMap { $0 }
            XCTAssertEqual(
                merged.filter {
                    $0.stableIdentifier == whatsapp.stableIdentifier
                }.count,
                1
            )
            XCTAssertTrue(
                merged.contains {
                    $0.stableIdentifier == safari.stableIdentifier
                }
            )
        }
    }

    func testEligibilityRequiresRegularUserFacingApplication() {
        let policy = WheelContextEligibilityPolicy()
        XCTAssertTrue(policy.allows(
            activationPolicy: .regular,
            bundleIdentifier: "com.apple.Safari",
            applicationURL: URL(fileURLWithPath: "/Applications/Safari.app"),
            localizedName: "Safari",
            isTerminated: false
        ))
        XCTAssertFalse(policy.allows(
            activationPolicy: .accessory,
            bundleIdentifier: "com.example.helper",
            applicationURL: URL(fileURLWithPath: "/Applications/Example.app"),
            localizedName: "Helper",
            isTerminated: false
        ))
        XCTAssertFalse(policy.allows(
            activationPolicy: .regular,
            bundleIdentifier: "com.apple.SecurityAgent",
            applicationURL: URL(fileURLWithPath: "/System/Library/CoreServices/SecurityAgent.app"),
            localizedName: "SecurityAgent",
            isTerminated: false
        ))
    }
}
