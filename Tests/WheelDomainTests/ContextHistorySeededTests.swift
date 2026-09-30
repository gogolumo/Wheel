import Foundation
import XCTest
@testable import WheelDomain

final class ContextHistorySeededTests: XCTestCase {
    func testSeededOperationSequencesMatchReferenceModel() {
        var acceptedRecords = 0
        var ignoredDuplicates = 0
        var acceptedNavigations = 0
        var rejectedBoundaryNavigations = 0
        var rejectedBlockedResults = 0
        var rejectedWrongTargets = 0
        var rejectedNoneDirections = 0
        var clearOperations = 0

        for seed in 1...64 {
            var generator = HistorySeededGenerator(seed: UInt64(seed))
            var history = ContextHistory()
            var reference = ReferenceHistory()

            for step in 0..<256 {
                let random = generator.next()

                switch random >> 61 {
                case 0:
                    let candidate = entry(
                        seed: seed,
                        step: step,
                        salt: 0,
                        token: "independent-\(seed)-\(step)"
                    )
                    let expected = reference.recordIndependent(candidate)

                    XCTAssertEqual(
                        history.recordIndependent(candidate),
                        expected,
                        context(seed: seed, step: step)
                    )
                    acceptedRecords += expected ? 1 : 0

                case 1:
                    let candidate: ContextEntry
                    if let current = reference.current {
                        candidate = entry(
                            seed: seed,
                            step: step,
                            salt: 1,
                            token: current.contextToken ?? "duplicate",
                            bundleID: current.applicationBundleID
                        )
                    } else {
                        candidate = entry(
                            seed: seed,
                            step: step,
                            salt: 1,
                            token: "first-\(seed)-\(step)"
                        )
                    }
                    let expected = reference.recordIndependent(candidate)

                    XCTAssertEqual(
                        history.recordIndependent(candidate),
                        expected,
                        context(seed: seed, step: step)
                    )
                    if expected {
                        acceptedRecords += 1
                    } else {
                        ignoredDuplicates += 1
                    }

                case 2, 3:
                    let direction: Direction = ((random >> 60) & 1) == 0 ? .left : .right
                    let target = reference.target(for: direction)
                    let targetID = target?.id ?? deterministicID(seed: seed, step: step, salt: 20)
                    let status: RestorationStatus = ((random >> 59) & 1) == 0 ? .success : .partial
                    let result = RestorationResult(status: status, depth: .application)
                    let expected = reference.commitNavigation(
                        direction: direction,
                        targetID: targetID,
                        result: result
                    )

                    XCTAssertEqual(
                        history.commitNavigation(
                            direction: direction,
                            targetID: targetID,
                            result: result
                        ),
                        expected,
                        context(seed: seed, step: step)
                    )
                    if expected {
                        acceptedNavigations += 1
                    } else {
                        rejectedBoundaryNavigations += 1
                    }

                case 4:
                    let direction: Direction = ((random >> 60) & 1) == 0 ? .left : .right
                    let targetID = reference.target(for: direction)?.id
                        ?? deterministicID(seed: seed, step: step, salt: 30)
                    let blockedStatuses: [RestorationStatus] = [
                        .failed,
                        .cancelled,
                        .unavailable,
                        .permissionDenied
                    ]
                    let statusIndex = Int(
                        (random >> 56) % UInt64(blockedStatuses.count)
                    )
                    let status = blockedStatuses[statusIndex]
                    let result = RestorationResult(status: status, depth: .none)

                    XCTAssertFalse(
                        reference.commitNavigation(
                            direction: direction,
                            targetID: targetID,
                            result: result
                        ),
                        context(seed: seed, step: step)
                    )
                    XCTAssertFalse(
                        history.commitNavigation(
                            direction: direction,
                            targetID: targetID,
                            result: result
                        ),
                        context(seed: seed, step: step)
                    )
                    rejectedBlockedResults += 1

                case 5:
                    let direction: Direction = ((random >> 60) & 1) == 0 ? .left : .right
                    let wrongTargetID = deterministicID(seed: seed, step: step, salt: 40)
                    let result = RestorationResult(status: .success, depth: .window)

                    XCTAssertFalse(
                        reference.commitNavigation(
                            direction: direction,
                            targetID: wrongTargetID,
                            result: result
                        ),
                        context(seed: seed, step: step)
                    )
                    XCTAssertFalse(
                        history.commitNavigation(
                            direction: direction,
                            targetID: wrongTargetID,
                            result: result
                        ),
                        context(seed: seed, step: step)
                    )
                    rejectedWrongTargets += 1

                case 6:
                    let targetID = reference.current?.id
                        ?? deterministicID(seed: seed, step: step, salt: 50)
                    let result = RestorationResult(status: .success, depth: .semantic)

                    XCTAssertFalse(
                        reference.commitNavigation(
                            direction: .none,
                            targetID: targetID,
                            result: result
                        ),
                        context(seed: seed, step: step)
                    )
                    XCTAssertFalse(
                        history.commitNavigation(
                            direction: .none,
                            targetID: targetID,
                            result: result
                        ),
                        context(seed: seed, step: step)
                    )
                    rejectedNoneDirections += 1

                default:
                    reference.clear()
                    history.clear()
                    clearOperations += 1
                }

                assertEquivalent(
                    history,
                    reference,
                    seed: seed,
                    step: step
                )
            }
        }

        XCTAssertGreaterThan(acceptedRecords, 0)
        XCTAssertGreaterThan(ignoredDuplicates, 0)
        XCTAssertGreaterThan(acceptedNavigations, 0)
        XCTAssertGreaterThan(rejectedBoundaryNavigations, 0)
        XCTAssertGreaterThan(rejectedBlockedResults, 0)
        XCTAssertGreaterThan(rejectedWrongTargets, 0)
        XCTAssertGreaterThan(rejectedNoneDirections, 0)
        XCTAssertGreaterThan(clearOperations, 0)
    }

    private func assertEquivalent(
        _ history: ContextHistory,
        _ reference: ReferenceHistory,
        seed: Int,
        step: Int
    ) {
        let message = context(seed: seed, step: step)

        XCTAssertEqual(history.entries, reference.entries, message)
        XCTAssertEqual(history.currentPosition, reference.currentPosition, message)
        XCTAssertEqual(history.current, reference.current, message)
        XCTAssertEqual(history.target(for: .left), reference.target(for: .left), message)
        XCTAssertEqual(history.target(for: .right), reference.target(for: .right), message)
        XCTAssertNil(history.target(for: .none), message)

        if history.entries.isEmpty {
            XCTAssertEqual(history.currentPosition, -1, message)
        } else {
            XCTAssertTrue(history.entries.indices.contains(history.currentPosition), message)
        }
    }

    private func entry(
        seed: Int,
        step: Int,
        salt: Int,
        token: String,
        bundleID: String = "dev.wheel.seeded-history"
    ) -> ContextEntry {
        ContextEntry(
            id: deterministicID(seed: seed, step: step, salt: salt),
            applicationBundleID: bundleID,
            contextToken: token,
            capturedAt: Date(timeIntervalSince1970: TimeInterval(step))
        )
    }

    private func deterministicID(seed: Int, step: Int, salt: Int) -> UUID {
        let value = UInt64(seed) * 1_000_000 + UInt64(step) * 100 + UInt64(salt)
        return UUID(
            uuidString: String(
                format: "00000000-0000-0000-0000-%012llx",
                value
            )
        )!
    }

    private func context(seed: Int, step: Int) -> String {
        "seed \(seed), step \(step)"
    }
}

private struct ReferenceHistory {
    private(set) var entries: [ContextEntry] = []
    private(set) var currentPosition = -1

    var current: ContextEntry? {
        guard entries.indices.contains(currentPosition) else { return nil }
        return entries[currentPosition]
    }

    func target(for direction: Direction) -> ContextEntry? {
        let targetPosition: Int
        switch direction {
        case .left:
            targetPosition = currentPosition - 1
        case .right:
            targetPosition = currentPosition + 1
        case .none:
            return nil
        }

        guard entries.indices.contains(targetPosition) else { return nil }
        return entries[targetPosition]
    }

    mutating func recordIndependent(_ entry: ContextEntry) -> Bool {
        guard current?.semanticKey != entry.semanticKey else { return false }

        if currentPosition >= 0, currentPosition < entries.count - 1 {
            entries = Array(entries.prefix(currentPosition + 1))
        }
        entries.append(entry)
        currentPosition = entries.count - 1
        return true
    }

    mutating func commitNavigation(
        direction: Direction,
        targetID: ContextEntry.ID,
        result: RestorationResult
    ) -> Bool {
        guard result.allowsPositionChange else { return false }
        guard let target = target(for: direction), target.id == targetID else { return false }

        currentPosition += direction == .left ? -1 : 1
        return true
    }

    mutating func clear() {
        entries = []
        currentPosition = -1
    }
}

private struct HistorySeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
