import XCTest
@testable import WheelMacOS

final class MouseButtonTriggerStateTests: XCTestCase {
    func testMatchingPressAndReleaseProduceOnePairOfEdges() {
        var state = MouseButtonTriggerState(buttonNumber: 3)

        XCTAssertEqual(
            state.consume(eventButtonNumber: 3, isDown: true),
            .pressed
        )
        XCTAssertTrue(state.isPressed)
        XCTAssertEqual(
            state.consume(eventButtonNumber: 3, isDown: false),
            .released
        )
        XCTAssertFalse(state.isPressed)
    }

    func testRepeatedPressAndStrayReleaseAreIgnored() {
        var state = MouseButtonTriggerState(buttonNumber: 3)

        XCTAssertNil(state.consume(eventButtonNumber: 3, isDown: false))
        XCTAssertEqual(
            state.consume(eventButtonNumber: 3, isDown: true),
            .pressed
        )
        XCTAssertNil(state.consume(eventButtonNumber: 3, isDown: true))
        XCTAssertEqual(
            state.consume(eventButtonNumber: 3, isDown: false),
            .released
        )
    }

    func testOtherButtonsDoNotChangeConfiguredButtonState() {
        var state = MouseButtonTriggerState(buttonNumber: 4)

        XCTAssertFalse(state.matches(3))
        XCTAssertTrue(state.matches(4))
        XCTAssertNil(state.consume(eventButtonNumber: 3, isDown: true))
        XCTAssertFalse(state.isPressed)
    }

    func testResetRequiresANewPressBeforeRelease() {
        var state = MouseButtonTriggerState(buttonNumber: 3)

        XCTAssertEqual(
            state.consume(eventButtonNumber: 3, isDown: true),
            .pressed
        )
        state.reset()

        XCTAssertFalse(state.isPressed)
        XCTAssertNil(state.consume(eventButtonNumber: 3, isDown: false))
    }
}
