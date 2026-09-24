import Foundation
import XCTest
@testable import WheelMacOS

final class WheelApplicationHistoryStoreTests: XCTestCase {
    func testConsecutiveActivationUpdatesCurrentEntryWithoutAppendingDuplicate() async {
        await MainActor.run {
            let persistence = InMemoryApplicationHistoryPersistence()
            let store = WheelApplicationHistoryStore(persistence: persistence)
            let safari = observation(name: "Safari", bundle: "com.apple.Safari", pid: 10)

            store.recordActivation(
                safari,
                at: Date(timeIntervalSince1970: 10),
                capacity: 50
            )
            store.recordActivation(
                safari,
                at: Date(timeIntervalSince1970: 20),
                capacity: 50
            )

            XCTAssertEqual(store.entries.count, 1)
            XCTAssertEqual(
                store.entries[0].lastActivatedAt,
                Date(timeIntervalSince1970: 20)
            )
        }
    }

    func testNonConsecutiveActivationPreservesRealTransitions() async {
        await MainActor.run {
            let store = WheelApplicationHistoryStore(
                persistence: InMemoryApplicationHistoryPersistence()
            )
            let safari = observation(name: "Safari", bundle: "com.apple.Safari", pid: 10)
            let finder = observation(name: "Finder", bundle: "com.apple.finder", pid: 11)

            store.recordActivation(safari, capacity: 50)
            store.recordActivation(finder, capacity: 50)
            store.recordActivation(safari, capacity: 50)

            XCTAssertEqual(
                store.entries.map(\.localizedName),
                ["Safari", "Finder", "Safari"]
            )
            XCTAssertEqual(
                store.wheelEntries(limit: 8).map(\.localizedName),
                ["Finder"]
            )
        }
    }

    func testTerminatedApplicationRemainsSelectableWhenRememberingClosedApps() async {
        await MainActor.run {
            let store = WheelApplicationHistoryStore(
                persistence: InMemoryApplicationHistoryPersistence()
            )
            let safari = observation(name: "Safari", bundle: "com.apple.Safari", pid: 10)
            let finder = observation(name: "Finder", bundle: "com.apple.finder", pid: 11)

            store.recordActivation(safari, capacity: 50)
            store.recordActivation(finder, capacity: 50)
            store.recordTermination(
                safari,
                rememberClosedApplications: true
            )

            let target = try? XCTUnwrap(
                store.wheelEntries(limit: 8).first
            )
            XCTAssertEqual(target?.localizedName, "Safari")
            XCTAssertEqual(target?.runState, .terminated)
        }
    }

    func testTerminatedApplicationIsRemovedWhenSettingIsOff() async {
        await MainActor.run {
            let store = WheelApplicationHistoryStore(
                persistence: InMemoryApplicationHistoryPersistence()
            )
            let safari = observation(name: "Safari", bundle: "com.apple.Safari", pid: 10)
            let finder = observation(name: "Finder", bundle: "com.apple.finder", pid: 11)

            store.recordActivation(safari, capacity: 50)
            store.recordActivation(finder, capacity: 50)
            store.recordTermination(
                safari,
                rememberClosedApplications: false
            )

            XCTAssertFalse(
                store.entries.contains {
                    $0.stableIdentifier == safari.stableIdentifier
                }
            )
        }
    }

    func testRestoredActivationMovesCurrentPointerWithoutAppending() async {
        await MainActor.run {
            let store = WheelApplicationHistoryStore(
                persistence: InMemoryApplicationHistoryPersistence()
            )
            let safari = observation(name: "Safari", bundle: "com.apple.Safari", pid: 10)
            let finder = observation(name: "Finder", bundle: "com.apple.finder", pid: 11)

            store.recordActivation(safari, capacity: 50)
            store.recordActivation(finder, capacity: 50)
            let countBeforeRestore = store.entries.count

            store.recordRestoredActivation(safari)

            XCTAssertEqual(store.entries.count, countBeforeRestore)
            XCTAssertEqual(
                store.currentIdentifier,
                safari.stableIdentifier
            )
        }
    }

    func testCapacityTrimsOldestTransitions() async {
        await MainActor.run {
            let store = WheelApplicationHistoryStore(
                persistence: InMemoryApplicationHistoryPersistence()
            )

            for index in 0..<5 {
                store.recordActivation(
                    observation(
                        name: "App \(index)",
                        bundle: "example.app.\(index)",
                        pid: Int32(100 + index)
                    ),
                    capacity: 3
                )
            }

            XCTAssertEqual(store.entries.count, 3)
            XCTAssertEqual(
                store.entries.map(\.localizedName),
                ["App 4", "App 3", "App 2"]
            )
        }
    }

    private func observation(
        name: String,
        bundle: String,
        pid: Int32
    ) -> WheelObservedApplication {
        WheelObservedApplication(
            localizedName: name,
            bundleIdentifier: bundle,
            applicationURL: URL(
                fileURLWithPath: "/Applications/\(name).app"
            ),
            processIdentifier: pid
        )
    }
}

private final class InMemoryApplicationHistoryPersistence:
    WheelApplicationHistoryPersisting
{
    var snapshot: WheelApplicationHistorySnapshot?

    func load() -> WheelApplicationHistorySnapshot? {
        snapshot
    }

    func save(_ snapshot: WheelApplicationHistorySnapshot) {
        self.snapshot = snapshot
    }
}
