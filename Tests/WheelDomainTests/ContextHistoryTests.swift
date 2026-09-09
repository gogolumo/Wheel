import XCTest
@testable import WheelDomain

final class ContextHistoryTests: XCTestCase {
    private func entry(_ token: String) -> ContextEntry {
        ContextEntry(
            applicationBundleID: "dev.wheel.tests",
            contextToken: token,
            capturedAt: Date(timeIntervalSince1970: 0)
        )
    }

    func testBackPreservesForwardBranch() throws {
        let a = entry("A")
        let b = entry("B")
        let c = entry("C")

        var history = ContextHistory(entries: [a, b, c])

        let target = try XCTUnwrap(history.target(for: .left))
        XCTAssertTrue(
            history.commitNavigation(
                direction: .left,
                targetID: target.id,
                result: RestorationResult(status: .success, depth: .window)
            )
        )

        XCTAssertEqual(history.entries, [a, b, c])
        XCTAssertEqual(history.current, b)
        XCTAssertEqual(history.target(for: .right), c)
    }

    func testIndependentEntryAfterBackReplacesForwardSuffix() {
        let a = entry("A")
        let b = entry("B")
        let c = entry("C")
        let d = entry("D")

        var history = ContextHistory(entries: [a, b, c])

        let target = try! XCTUnwrap(history.target(for: .left))
        XCTAssertTrue(
            history.commitNavigation(
                direction: .left,
                targetID: target.id,
                result: RestorationResult(status: .success, depth: .window)
            )
        )

        XCTAssertTrue(history.recordIndependent(d))
        XCTAssertEqual(history.entries, [a, b, d])
        XCTAssertEqual(history.current, d)
        XCTAssertNil(history.target(for: .right))
    }

    func testFailedRestoreDoesNotMovePosition() throws {
        let a = entry("A")
        let b = entry("B")
        var history = ContextHistory(entries: [a, b])

        let target = try XCTUnwrap(history.target(for: .left))

        XCTAssertFalse(
            history.commitNavigation(
                direction: .left,
                targetID: target.id,
                result: RestorationResult(status: .failed, depth: .none)
            )
        )

        XCTAssertEqual(history.current, b)
    }

    func testCancelledRestoreDoesNotMovePosition() throws {
        let a = entry("A")
        let b = entry("B")
        var history = ContextHistory(entries: [a, b])

        let target = try XCTUnwrap(history.target(for: .left))

        XCTAssertFalse(
            history.commitNavigation(
                direction: .left,
                targetID: target.id,
                result: RestorationResult(status: .cancelled, depth: .none)
            )
        )

        XCTAssertEqual(history.current, b)
    }

    func testDuplicateCurrentContextIsIgnored() {
        let a = entry("A")
        var history = ContextHistory(entries: [a])

        let duplicateA = entry("A")

        XCTAssertFalse(history.recordIndependent(duplicateA))
        XCTAssertEqual(history.entries.count, 1)
        XCTAssertEqual(history.current?.semanticKey, a.semanticKey)
    }

    func testEmptyHistoryHasNoTargets() {
        let history = ContextHistory()
        XCTAssertEqual(history.currentPosition, -1)
        XCTAssertNil(history.target(for: .left))
        XCTAssertNil(history.target(for: .right))
    }

    func testWrongTargetCannotCommit() {
        let a = entry("A")
        let b = entry("B")
        let unrelated = entry("X")
        var history = ContextHistory(entries: [a, b])

        XCTAssertFalse(
            history.commitNavigation(
                direction: .left,
                targetID: unrelated.id,
                result: RestorationResult(status: .success, depth: .window)
            )
        )

        XCTAssertEqual(history.current, b)
    }
}
