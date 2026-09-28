import Foundation
import XCTest
import WheelDomain
@testable import WheelMacOS

final class WheelSectorLayoutTests: XCTestCase {
    func testRightVectorSelectsFirstSectorForSupportedCounts() {
        for count in [2, 4, 6, 8, 10, 12] {
            XCTAssertEqual(
                WheelSectorLayout.selectedIndex(
                    displacement: .init(horizontal: 100, vertical: 0),
                    sectorCount: count,
                    minimumDistance: 20
                ),
                0,
                "sector count \(count)"
            )
        }
    }

    func testFourDirectionsMapClockwiseInScreenCoordinates() {
        XCTAssertEqual(index(horizontal: 100, vertical: 0, count: 4), 0)
        XCTAssertEqual(index(horizontal: 0, vertical: 100, count: 4), 1)
        XCTAssertEqual(index(horizontal: -100, vertical: 0, count: 4), 2)
        XCTAssertEqual(index(horizontal: 0, vertical: -100, count: 4), 3)
    }

    func testMovementBelowThresholdSelectsNothing() {
        XCTAssertNil(
            WheelSectorLayout.selectedIndex(
                displacement: .init(horizontal: 10, vertical: 10),
                sectorCount: 8,
                minimumDistance: 80
            )
        )
    }

    func testAnglesAreEvenlySpacedAndFinite() {
        for count in [4, 6, 8, 10] {
            let angles = (0..<count).map {
                WheelSectorLayout.angle(for: $0, sectorCount: count)
            }
            XCTAssertTrue(angles.allSatisfy(\.isFinite))

            let expectedSpacing = (Double.pi * 2) / Double(count)
            for index in 1..<angles.count {
                XCTAssertEqual(
                    angles[index] - angles[index - 1],
                    expectedSpacing,
                    accuracy: 0.000_001
                )
            }
        }
    }

    private func index(
        horizontal: Double,
        vertical: Double,
        count: Int
    ) -> Int? {
        WheelSectorLayout.selectedIndex(
            displacement: .init(
                horizontal: horizontal,
                vertical: vertical
            ),
            sectorCount: count,
            minimumDistance: 20
        )
    }
}
