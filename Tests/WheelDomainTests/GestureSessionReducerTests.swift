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

    func testSeededEventSequencesNeverCreateOverlappingSessions() {
        for seed in 0..<64 {
            var generator = SeededGenerator(seed: UInt64(seed) + 1)
            var reducer = GestureSessionReducer()
            var acceptedStarts = 0
            var acceptedTerminals = 0

            for step in 0..<256 {
                let event: GestureSessionEvent
                switch generator.next() % 5 {
                case 0:
                    let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012llx", UInt64(seed * 256 + step)))!
                    let trigger: TriggerType = generator.next() & 1 == 0 ? .capsLock : .rightOption
                    event = .start(id: id, triggerType: trigger)
                case 1:
                    event = .complete(.left)
                case 2:
                    event = .complete(.right)
                case 3:
                    event = .complete(.none)
                default:
                    event = .cancel
                }

                let wasTracking = reducer.activeSession != nil
                let accepted = reducer.reduce(event)

                switch event {
                case .start:
                    XCTAssertEqual(accepted, !wasTracking, "seed \(seed), step \(step)")
                    if accepted { acceptedStarts += 1 }
                case .complete, .cancel:
                    XCTAssertEqual(accepted, wasTracking, "seed \(seed), step \(step)")
                    if accepted { acceptedTerminals += 1 }
                }

                if let activeSession = reducer.activeSession {
                    XCTAssertEqual(activeSession.status, .tracking, "seed \(seed), step \(step)")
                }
                XCTAssertGreaterThanOrEqual(acceptedStarts, acceptedTerminals)
                XCTAssertLessThanOrEqual(acceptedStarts - acceptedTerminals, 1)
            }
        }
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
