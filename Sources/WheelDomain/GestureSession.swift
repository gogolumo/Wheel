import Foundation

public enum GestureStatus: Equatable, Sendable {
    case tracking
    case completed(Direction)
    case cancelled
}

public struct GestureSession: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let triggerType: TriggerType
    public private(set) var status: GestureStatus

    public init(
        id: UUID = UUID(),
        triggerType: TriggerType,
        status: GestureStatus = .tracking
    ) {
        self.id = id
        self.triggerType = triggerType
        self.status = status
    }

    public mutating func complete(direction: Direction) -> Bool {
        guard status == .tracking else { return false }
        status = .completed(direction)
        return true
    }

    public mutating func cancel() -> Bool {
        guard status == .tracking else { return false }
        status = .cancelled
        return true
    }
}
