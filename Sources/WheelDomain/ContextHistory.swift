import Foundation

public struct ContextHistory: Equatable, Sendable {
    public private(set) var entries: [ContextEntry]
    public private(set) var currentPosition: Int

    public init(entries: [ContextEntry] = [], currentPosition: Int? = nil) {
        self.entries = entries

        if entries.isEmpty {
            self.currentPosition = -1
        } else if let currentPosition {
            self.currentPosition = min(max(currentPosition, 0), entries.count - 1)
        } else {
            self.currentPosition = entries.count - 1
        }
    }

    public var current: ContextEntry? {
        guard entries.indices.contains(currentPosition) else { return nil }
        return entries[currentPosition]
    }

    public func target(for direction: Direction) -> ContextEntry? {
        switch direction {
        case .none:
            return nil
        case .left:
            let index = currentPosition - 1
            guard entries.indices.contains(index) else { return nil }
            return entries[index]
        case .right:
            let index = currentPosition + 1
            guard entries.indices.contains(index) else { return nil }
            return entries[index]
        }
    }

    /// Records a context reached through normal independent work.
    ///
    /// If the user previously navigated Back, this is the only operation that
    /// replaces the retained forward suffix.
    @discardableResult
    public mutating func recordIndependent(_ entry: ContextEntry) -> Bool {
        if current?.semanticKey == entry.semanticKey {
            return false
        }

        if currentPosition >= 0 && currentPosition < entries.count - 1 {
            entries.removeSubrange((currentPosition + 1)..<entries.count)
        }

        entries.append(entry)
        currentPosition = entries.count - 1
        return true
    }

    /// Commits a completed Wheel navigation attempt.
    ///
    /// A failed, cancelled, unavailable, or permission-denied restoration never
    /// changes currentPosition. Back/Forward navigation also never truncates
    /// history; branch replacement happens only in recordIndependent(_:).
    @discardableResult
    public mutating func commitNavigation(
        direction: Direction,
        targetID: ContextEntry.ID,
        result: RestorationResult
    ) -> Bool {
        guard result.allowsPositionChange else { return false }

        let expectedIndex: Int
        switch direction {
        case .left:
            expectedIndex = currentPosition - 1
        case .right:
            expectedIndex = currentPosition + 1
        case .none:
            return false
        }

        guard entries.indices.contains(expectedIndex) else { return false }
        guard entries[expectedIndex].id == targetID else { return false }

        currentPosition = expectedIndex
        return true
    }

    public mutating func clear() {
        entries.removeAll(keepingCapacity: false)
        currentPosition = -1
    }
}
