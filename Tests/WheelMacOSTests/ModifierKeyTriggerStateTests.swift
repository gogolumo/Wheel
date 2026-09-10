import XCTest
@testable import WheelMacOS

final class ModifierKeyTriggerStateTests: XCTestCase {
    func testMatchingPressAndReleaseProduceOnePairOfEdges() {
        var state = ModifierKeyTriggerState(keyCode: 61)

        XCTAssertEqual(
            state.consume(eventKeyCode: 61, modifierFlagEnabled: true),
            .pressed
        )
        XCTAssertTrue(state.isPressed)
        XCTAssertEqual(
            state.consume(eventKeyCode: 61, modifierFlagEnabled: false),
            .released
        )
        XCTAssertFalse(state.isPressed)
    }

    func testReleaseIsRecognizedWhileEquivalentModifierRemainsEnabled() {
        var state = ModifierKeyTriggerState(keyCode: 61)

        XCTAssertEqual(
            state.consume(eventKeyCode: 61, modifierFlagEnabled: true),
            .pressed
        )
        XCTAssertEqual(
            state.consume(eventKeyCode: 61, modifierFlagEnabled: true),
            .released
        )
        XCTAssertFalse(state.isPressed)
    }

    func testStrayReleaseAndOtherKeyAreIgnored() {
        var state = ModifierKeyTriggerState(keyCode: 61)

        XCTAssertNil(state.consume(eventKeyCode: 61, modifierFlagEnabled: false))
        XCTAssertNil(state.consume(eventKeyCode: 58, modifierFlagEnabled: true))
        XCTAssertFalse(state.isPressed)
    }

    func testResetRequiresANewPressBeforeRelease() {
        var state = ModifierKeyTriggerState(keyCode: 61)

        XCTAssertEqual(
            state.consume(eventKeyCode: 61, modifierFlagEnabled: true),
            .pressed
        )
        state.reset()

        XCTAssertFalse(state.isPressed)
        XCTAssertNil(state.consume(eventKeyCode: 61, modifierFlagEnabled: false))
    }
}
