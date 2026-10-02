import XCTest
@testable import WheelMacOS

final class WheelApplicationPresentationTests: XCTestCase {
    func testUnavailablePinStaysVisibleWithoutPromisingOpen() {
        let presentation = WheelApplicationPresentation(runState: .unavailable, isPinned: true)
        XCTAssertEqual(presentation.statusText, "Unavailable")
        XCTAssertNil(presentation.releaseInstruction)
        XCTAssertEqual(presentation.accessibilityState, "Unavailable, pinned")
        XCTAssertNotEqual(presentation.symbolName, WheelApplicationPresentation(runState: .running, isPinned: true).symbolName)
    }

    func testClosedApplicationOffersExistingReopenInsteadOfSwitch() {
        let closed = WheelApplicationPresentation(runState: .terminated, isPinned: false)
        let running = WheelApplicationPresentation(runState: .running, isPinned: false)
        XCTAssertEqual(closed.releaseInstruction, "Release to reopen")
        XCTAssertEqual(running.releaseInstruction, "Release to switch")
        XCTAssertNotEqual(closed.statusText, running.statusText)
        XCTAssertNotEqual(closed.symbolName, running.symbolName)
    }

    func testPinStateDoesNotChangeRestorationHint() {
        for state in [WheelApplicationRunState.running, .terminated, .unavailable] {
            let automatic = WheelApplicationPresentation(runState: state, isPinned: false)
            let pinned = WheelApplicationPresentation(runState: state, isPinned: true)
            XCTAssertEqual(automatic.releaseInstruction, pinned.releaseInstruction)
            XCTAssertEqual(automatic.statusText, pinned.statusText)
            XCTAssertEqual(pinned.accessibilityState, "\(automatic.statusText), pinned")
        }
    }
}
