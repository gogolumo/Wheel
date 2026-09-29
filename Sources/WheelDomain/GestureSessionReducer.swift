import Foundation

public enum GestureSessionEvent: Equatable, Sendable {
    case start(id: UUID, triggerType: TriggerType)
    case complete(id: UUID, direction: Direction)
    case cancel(id: UUID)
}

public struct GestureSessionReducer: Equatable, Sendable {
    public private(set) var activeSession: GestureSession?

    /// Restores only a session that can still accept terminal input.
    ///
    /// A completed or cancelled session is historical state, not an active
    /// session. Dropping it here prevents a reducer restored from a stale
    /// snapshot from becoming permanently unable to accept a new gesture.
    public init(activeSession: GestureSession? = nil) {
        if activeSession?.status == .tracking {
            self.activeSession = activeSession
        } else {
            self.activeSession = nil
        }
    }

    @discardableResult
    public mutating func reduce(_ event: GestureSessionEvent) -> Bool {
        switch event {
        case let .start(id, triggerType):
            guard activeSession == nil else { return false }
            activeSession = GestureSession(id: id, triggerType: triggerType)
            return true

        case let .complete(id, direction):
            guard var session = activeSession, session.id == id else { return false }
            guard session.complete(direction: direction) else { return false }
            activeSession = nil
            return true

        case let .cancel(id):
            guard var session = activeSession, session.id == id else { return false }
            guard session.cancel() else { return false }
            activeSession = nil
            return true
        }
    }
}
