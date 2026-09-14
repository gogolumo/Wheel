import XCTest
@testable import WheelDomain
@testable import WheelMacOS

final class InputSpikeRunStatisticsTests: XCTestCase {
    func testCountsCompletedSequencesByDirection() {
        var statistics = InputSpikeRunStatistics()

        statistics.recordCompletedSequence(direction: .left)
        statistics.recordCompletedSequence(direction: .right)
        statistics.recordCompletedSequence(direction: .none)
        statistics.recordCompletedSequence(direction: .left)

        XCTAssertEqual(statistics.completedSequenceCount, 4)
        XCTAssertEqual(statistics.leftCount, 2)
        XCTAssertEqual(statistics.rightCount, 1)
        XCTAssertEqual(statistics.noneCount, 1)
    }

    func testCalculatesMedianCallbackLatencyForOddAndEvenSamples() throws {
        var statistics = InputSpikeRunStatistics()

        statistics.recordCallbackLatency(milliseconds: 7)
        statistics.recordCallbackLatency(milliseconds: 1)
        statistics.recordCallbackLatency(milliseconds: 3)

        XCTAssertEqual(
            try XCTUnwrap(statistics.medianCallbackLatencyMilliseconds),
            3,
            accuracy: 0.001
        )

        statistics.recordCallbackLatency(milliseconds: 5)

        XCTAssertEqual(
            try XCTUnwrap(statistics.medianCallbackLatencyMilliseconds),
            4,
            accuracy: 0.001
        )
    }

    func testRejectsInvalidLatencySamples() {
        var statistics = InputSpikeRunStatistics()

        statistics.recordCallbackLatency(milliseconds: -1)
        statistics.recordCallbackLatency(milliseconds: .nan)
        statistics.recordCallbackLatency(milliseconds: .infinity)

        XCTAssertEqual(statistics.callbackSampleCount, 0)
        XCTAssertNil(statistics.medianCallbackLatencyMilliseconds)
    }

    func testCountsEventTapRecoveries() {
        var statistics = InputSpikeRunStatistics()

        statistics.recordEventTapRecovery()
        statistics.recordEventTapRecovery()

        XCTAssertEqual(statistics.eventTapRecoveryCount, 2)
    }

    func testCountsPointerMovementEvents() {
        var statistics = InputSpikeRunStatistics()

        statistics.recordPointerMovement()
        statistics.recordPointerMovement()
        statistics.recordPointerMovement()

        XCTAssertEqual(statistics.pointerMovementCount, 3)
    }
}
