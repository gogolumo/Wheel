import XCTest
@testable import WheelDomain

final class GestureSessionReducerTests: XCTestCase {
    func testDuplicateStartKeepsOriginalSessionActive() {
        let firstID = UUID()
        let duplicateID = UUID()
        var reducer = GestureSessionReducer()

        XCTAssertTrue(reducer.reduce(.start(id: firstID, triggerType: .capsLock)))
        XCTAssertFalse(reducer.reduce(.start(id: duplicateID, triggerType: .rightOption)))
        XCTAssertEqual(reducer.activeSession?.id, firstID)
        XCTAssertEqual(reducer.activeSession?.triggerType, .capsLock)
        XCTAssertEqual(reducer.activeSession?.status, .tracking)
    }

    func testTerminalEventClosesSessionAndDuplicateTerminalIsIgnored() {
        var reducer = GestureSessionReducer()

        XCTAssertTrue(reducer.reduce(.start(id: UUID(), triggerType: .rightOption)))
        XCTAssertTrue(reducer.reduce(.complete(.left)))
        XCTAssertNil(reducer.activeSession)
        XCTAssertFalse(reducer.reduce(.complete(.right)))
        XCTAssertFalse(reducer.reduce(.cancel))
    }

    func testCancelReturnsReducerToIdleAndAllowsNextSession() {
        let nextID = UUID()
        var reducer = GestureSessionReducer()

        XCTAssertTrue(reducer.reduce(.start(id: UUID(), triggerType: .capsLock)))
        XCTAssertTrue(reducer.reduce(.cancel))
        XCTAssertNil(reducer.activeSession)

        XCTAssertTrue(reducer.reduce(.start(id: nextID, triggerType: .rightOption)))
        XCTAssertEqual(reducer.activeSession?.id, nextID)
    }

    func testTerminalEventsAreIgnoredWhileIdle() {
        var reducer = GestureSessionReducer()

        XCTAssertFalse(reducer.reduce(.complete(.left)))
        XCTAssertFalse(reducer.reduce(.cancel))
        XCTAssertNil(reducer.activeSession)
    }
}
