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
        let id = UUID()
        var reducer = GestureSessionReducer()

        XCTAssertTrue(reducer.reduce(.start(id: id, triggerType: .rightOption)))
        XCTAssertTrue(reducer.reduce(.complete(id: id, direction: .left)))
        XCTAssertNil(reducer.activeSession)
        XCTAssertFalse(reducer.reduce(.complete(id: id, direction: .right)))
        XCTAssertFalse(reducer.reduce(.cancel(id: id)))
    }

    func testCancelReturnsReducerToIdleAndAllowsNextSession() {
        let firstID = UUID()
        let nextID = UUID()
        var reducer = GestureSessionReducer()

        XCTAssertTrue(reducer.reduce(.start(id: firstID, triggerType: .capsLock)))
        XCTAssertTrue(reducer.reduce(.cancel(id: firstID)))
        XCTAssertNil(reducer.activeSession)

        XCTAssertTrue(reducer.reduce(.start(id: nextID, triggerType: .rightOption)))
        XCTAssertEqual(reducer.activeSession?.id, nextID)
    }

    func testTerminalEventsAreIgnoredWhileIdle() {
        let id = UUID()
        var reducer = GestureSessionReducer()

        XCTAssertFalse(reducer.reduce(.complete(id: id, direction: .left)))
        XCTAssertFalse(reducer.reduce(.cancel(id: id)))
        XCTAssertNil(reducer.activeSession)
    }

    func testStaleTerminalCallbacksCannotCloseNewSession() {
        let firstID = UUID()
        let secondID = UUID()
        var reducer = GestureSessionReducer()

        XCTAssertTrue(reducer.reduce(.start(id: firstID, triggerType: .capsLock)))
        XCTAssertTrue(reducer.reduce(.complete(id: firstID, direction: .left)))
        XCTAssertTrue(reducer.reduce(.start(id: secondID, triggerType: .rightOption)))

        XCTAssertFalse(reducer.reduce(.complete(id: firstID, direction: .right)))
        XCTAssertFalse(reducer.reduce(.cancel(id: firstID)))
        XCTAssertEqual(reducer.activeSession?.id, secondID)
        XCTAssertEqual(reducer.activeSession?.status, .tracking)
    }

    func testSeededEventSequencesNeverCreateOverlappingSessions() {
        for seed in 0..<64 {
            var generator = SeededGenerator(seed: UInt64(seed) + 1)
            var reducer = GestureSessionReducer()
            var acceptedStarts = 0
            var acceptedTerminals = 0

            for step in 0..<256 {
                let activeID = reducer.activeSession?.id
                let terminalID = generator.next() & 3 == 0
                    ? deterministicID(seed: seed, step: step, salt: 1)
                    : (activeID ?? deterministicID(seed: seed, step: step, salt: 2))
                let event: GestureSessionEvent
                switch generator.next() % 5 {
                case 0:
                    let id = deterministicID(seed: seed, step: step, salt: 0)
                    let trigger: TriggerType = generator.next() & 1 == 0 ? .capsLock : .rightOption
                    event = .start(id: id, triggerType: trigger)
                case 1:
                    event = .complete(id: terminalID, direction: .left)
                case 2:
                    event = .complete(id: terminalID, direction: .right)
                case 3:
                    event = .complete(id: terminalID, direction: .none)
                default:
                    event = .cancel(id: terminalID)
                }

                let sessionBefore = reducer.activeSession
                let accepted = reducer.reduce(event)

                switch event {
                case .start:
                    XCTAssertEqual(accepted, sessionBefore == nil, "seed \(seed), step \(step)")
                    if accepted { acceptedStarts += 1 }
                case let .complete(id, _), let .cancel(id):
                    let expectedAcceptance = sessionBefore?.id == id
                    XCTAssertEqual(accepted, expectedAcceptance, "seed \(seed), step \(step)")
                    if accepted { acceptedTerminals += 1 }
                    if !expectedAcceptance {
                        XCTAssertEqual(reducer.activeSession, sessionBefore, "seed \(seed), step \(step)")
                    }
                }

                if let activeSession = reducer.activeSession {
                    XCTAssertEqual(activeSession.status, .tracking, "seed \(seed), step \(step)")
                }
                XCTAssertGreaterThanOrEqual(acceptedStarts, acceptedTerminals)
                XCTAssertLessThanOrEqual(acceptedStarts - acceptedTerminals, 1)
            }
        }
    }

    private func deterministicID(seed: Int, step: Int, salt: Int) -> UUID {
        let value = UInt64(seed * 1_024 + step * 4 + salt)
        return UUID(
            uuidString: String(
                format: "00000000-0000-0000-0000-%012llx",
                value
            )
        )!
    }
}

private struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
