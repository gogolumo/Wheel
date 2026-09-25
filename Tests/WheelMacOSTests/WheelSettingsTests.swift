import Foundation
import XCTest
@testable import WheelMacOS

final class WheelSettingsTests: XCTestCase {
    func testDefaultsMatchMVPConfiguration() async {
        let suiteName = "WheelSettingsTests.defaults.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        await MainActor.run {
            let settings = WheelSettings(defaults: defaults)

            XCTAssertEqual(settings.visibleItemCount, 8)
            XCTAssertEqual(settings.directionCount, 8)
            XCTAssertEqual(settings.historyCapacity, 50)
            XCTAssertTrue(settings.rememberClosedApplications)
        }
    }

    func testValuesPersistAndUnsupportedDirectionsAreRejected() async {
        let suiteName = "WheelSettingsTests.persistence.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        await MainActor.run {
            let first = WheelSettings(defaults: defaults)
            first.setVisibleItemCount(12)
            first.setDirectionCount(6)
            first.setHistoryCapacity(90)
            first.setRememberClosedApplications(false)
            first.setDirectionCount(5)

            let second = WheelSettings(defaults: defaults)
            XCTAssertEqual(second.visibleItemCount, 12)
            XCTAssertEqual(second.directionCount, 6)
            XCTAssertEqual(second.historyCapacity, 90)
            XCTAssertFalse(second.rememberClosedApplications)
        }
    }
}
