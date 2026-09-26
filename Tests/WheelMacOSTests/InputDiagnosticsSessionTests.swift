import Foundation
import XCTest
@testable import WheelDomain
@testable import WheelMacOS

final class InputDiagnosticsSessionTests: XCTestCase {
    func testPermissionMissingAndGrantedStates() {
        var session = InputDiagnosticsSession(permissionGranted: false)

        XCTAssertEqual(session.status, .permissionRequired)
        XCTAssertFalse(session.permissionGranted)

        session.updatePermission(true)

        XCTAssertEqual(session.status, .ready)
        XCTAssertTrue(session.permissionGranted)
    }

    func testStartTransitionsToListening() throws {
        var session = InputDiagnosticsSession(permissionGranted: true)

        try session.start(configuration: configuration())

        XCTAssertEqual(session.status, .listening)
        XCTAssertTrue(session.isListening)
        XCTAssertFalse(session.triggerIsHeld)
    }

    func testTriggerBeginTransitionsToHeld() throws {
        var session = InputDiagnosticsSession(permissionGranted: true)
        try session.start(configuration: configuration())

        session.handle(.triggerBegan(origin: .init(x: 10, y: 20)))

        XCTAssertEqual(session.status, .triggerHeld)
        XCTAssertTrue(session.triggerIsHeld)
    }

    func testTriggerEndRecordsOneDirectionAndProgress() throws {
        var session = InputDiagnosticsSession(permissionGranted: true)
        try session.start(configuration: configuration(target: 2))
        session.handle(.triggerBegan(origin: .init(x: 0, y: 0)))

        let action = session.handle(
            .triggerEnded(
                direction: .left,
                displacement: .init(horizontal: -120, vertical: 4),
                duration: 0.2
            )
        )

        XCTAssertEqual(action, .none)
        XCTAssertEqual(session.status, .listening)
        XCTAssertEqual(session.statistics.completedSequenceCount, 1)
        XCTAssertEqual(session.statistics.leftCount, 1)
        XCTAssertEqual(session.lastDirection, .left)
    }

    func testTargetReachedCompletesAndRequestsMonitorStop() throws {
        var session = InputDiagnosticsSession(permissionGranted: true)
        try session.start(configuration: configuration(target: 1))
        session.handle(.triggerBegan(origin: .init(x: 0, y: 0)))

        let action = session.handle(
            .triggerEnded(
                direction: .right,
                displacement: .init(horizontal: 120, vertical: 0),
                duration: 0.1
            )
        )

        XCTAssertEqual(action, .stopMonitoring)
        XCTAssertEqual(session.status, .completed)
        XCTAssertFalse(session.isListening)
        XCTAssertEqual(session.completionReason, .targetReached)
    }

    func testStopBeforeTargetMakesPartialEvidenceAvailable() throws {
        var session = InputDiagnosticsSession(permissionGranted: true)
        try session.start(configuration: configuration(target: 30))
        session.handle(.triggerBegan(origin: .init(x: 0, y: 0)))
        session.handle(
            .triggerEnded(
                direction: .none,
                displacement: .init(horizontal: 2, vertical: 1),
                duration: 0.1
            )
        )

        session.stop()
        let summary = try session.makeSummary()

        XCTAssertEqual(session.status, .stopped)
        XCTAssertTrue(session.evidenceAvailable)
        XCTAssertEqual(summary.completionReason, .interrupted)
        XCTAssertFalse(summary.observedTargetMet)
        XCTAssertEqual(summary.completedSequenceCount, 1)
    }

    func testEventTapRecoveryClearsHeldStateAndCountsRecovery() throws {
        var session = InputDiagnosticsSession(permissionGranted: true)
        try session.start(configuration: configuration())
        session.handle(.triggerBegan(origin: .init(x: 0, y: 0)))

        session.handle(.eventTapRecovered)

        XCTAssertEqual(session.status, .eventTapRecovered)
        XCTAssertTrue(session.isListening)
        XCTAssertFalse(session.triggerIsHeld)
        XCTAssertEqual(session.statistics.eventTapRecoveryCount, 1)
    }

    func testResetClearsCountersAndLastDirection() throws {
        var session = InputDiagnosticsSession(permissionGranted: true)
        try session.start(configuration: configuration())
        session.handle(.triggerBegan(origin: .init(x: 0, y: 0)))
        session.handle(
            .triggerEnded(
                direction: .left,
                displacement: .init(horizontal: -100, vertical: 0),
                duration: 0.1
            )
        )
        session.stop()

        session.reset(permissionGranted: true)

        XCTAssertEqual(session.status, .ready)
        XCTAssertEqual(session.statistics.completedSequenceCount, 0)
        XCTAssertNil(session.lastDirection)
        XCTAssertFalse(session.evidenceAvailable)
        XCTAssertFalse(session.evidenceSaved)
    }

    func testDuplicateBeginAndEndDoNotDuplicateSequence() throws {
        var session = InputDiagnosticsSession(permissionGranted: true)
        try session.start(configuration: configuration(target: 3))
        session.handle(.triggerBegan(origin: .init(x: 0, y: 0)))
        session.handle(.triggerBegan(origin: .init(x: 5, y: 5)))

        let end = GlobalInputEvent.triggerEnded(
            direction: .right,
            displacement: .init(horizontal: 100, vertical: 0),
            duration: 0.1
        )
        session.handle(end)
        session.handle(end)

        XCTAssertEqual(session.statistics.completedSequenceCount, 1)
        XCTAssertEqual(session.statistics.rightCount, 1)
    }

    func testMouseButtonNumberIsOnlyIncludedForMouseTrigger() throws {
        var mouseSession = InputDiagnosticsSession(permissionGranted: true)
        try mouseSession.start(
            configuration: configuration(trigger: .mouseSideButton, mouseButton: 5)
        )
        mouseSession.stop()

        var optionSession = InputDiagnosticsSession(permissionGranted: true)
        try optionSession.start(
            configuration: configuration(trigger: .rightOption, mouseButton: 5)
        )
        optionSession.stop()

        XCTAssertEqual(try mouseSession.makeSummary().mouseButtonNumber, 5)
        XCTAssertNil(try optionSession.makeSummary().mouseButtonNumber)
    }

    func testPointerMovementCountsOnlyWhileTriggerIsHeld() throws {
        var session = InputDiagnosticsSession(permissionGranted: true)
        try session.start(configuration: configuration())

        session.handle(.pointerMoved(displacement: .init(horizontal: 1, vertical: 1)))
        session.handle(.triggerBegan(origin: .init(x: 0, y: 0)))
        session.handle(.pointerMoved(displacement: .init(horizontal: 2, vertical: 1)))

        XCTAssertEqual(session.statistics.pointerMovementCount, 1)
    }

    func testSystemWakeStopsSessionAndClearsHeldState() throws {
        var session = InputDiagnosticsSession(permissionGranted: true)
        try session.start(configuration: configuration())
        session.handle(.triggerBegan(origin: .init(x: 0, y: 0)))

        session.interruptAfterSystemWake()

        XCTAssertEqual(session.status, .stopped)
        XCTAssertFalse(session.isListening)
        XCTAssertFalse(session.triggerIsHeld)
        XCTAssertEqual(session.completionReason, .interrupted)
        XCTAssertNotNil(session.notice)
    }

    func testModifierSignalsProvideTransientEdgeFeedback() throws {
        var session = InputDiagnosticsSession(permissionGranted: true)
        try session.start(configuration: configuration())

        session.handle(
            .modifierSignal(keyCode: 61, sampledDown: true, alphaShiftEnabled: false)
        )
        session.handle(
            .modifierSignal(keyCode: 61, sampledDown: false, alphaShiftEnabled: false)
        )

        XCTAssertEqual(session.matchingTriggerSignalCount, 2)
        XCTAssertEqual(session.lastTriggerSignalIsDown, false)
    }

    func testOnlyConfiguredMouseButtonSignalsProvideEdgeFeedback() throws {
        var session = InputDiagnosticsSession(permissionGranted: true)
        try session.start(
            configuration: configuration(trigger: .mouseSideButton, mouseButton: 5)
        )

        session.handle(
            .mouseButtonSignal(buttonNumber: 3, isDown: true, matchesConfiguredButton: false)
        )
        session.handle(
            .mouseButtonSignal(buttonNumber: 5, isDown: true, matchesConfiguredButton: true)
        )

        XCTAssertEqual(session.matchingTriggerSignalCount, 1)
        XCTAssertEqual(session.lastTriggerSignalIsDown, true)
    }

    func testTransientSignalFeedbackIsNotExported() throws {
        var session = InputDiagnosticsSession(permissionGranted: true)
        try session.start(configuration: configuration())
        session.handle(
            .modifierSignal(keyCode: 61, sampledDown: true, alphaShiftEnabled: false)
        )
        session.stop()

        let data = try JSONEncoder().encode(session.makeSummary())
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertFalse(json.contains("matchingTriggerSignalCount"))
        XCTAssertFalse(json.contains("lastTriggerSignalIsDown"))
        XCTAssertFalse(json.contains("keyCode"))
    }

    private func configuration(
        target: Int = 30,
        trigger: TriggerType = .rightOption,
        mouseButton: Int64 = 3
    ) -> InputDiagnosticsConfiguration {
        InputDiagnosticsConfiguration(
            runLabel: "unit-test",
            triggerType: trigger,
            targetSequenceCount: target,
            minimumHorizontalDistance: 80,
            minimumDominanceRatio: 1.5,
            mouseButtonNumber: mouseButton
        )
    }
}
