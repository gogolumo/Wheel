import Foundation

public enum GestureSessionEvent: Equatable, Sendable {
    case start(id: UUID, triggerType: TriggerType)
    case complete(Direction)
    case cancel
}

public struct GestureSessionReducer: Equatable, Sendable {
    public private(set) var activeSession: GestureSession?

    public init(activeSession: GestureSession? = nil) {
        self.activeSession = activeSession
    }

    @discardableResult
    public mutating func reduce(_ event: GestureSessionEvent) -> Bool {
        switch event {
        case let .start(id, triggerType):
            guard activeSession == nil else { return false }
            activeSession = GestureSession(id: id, triggerType: triggerType)
            return true

        case let .complete(direction):
            guard var session = activeSession else { return false }
            guard session.complete(direction: direction) else { return false }
            activeSession = nil
            return true

        case .cancel:
            guard var session = activeSession else { return false }
            guard session.cancel() else { return false }
            activeSession = nil
            return true
        }
    }
}
