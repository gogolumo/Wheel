import WheelDomain

public enum NavigationControllerError: Error, Equatable {
    case gestureAlreadyActive
    case noActiveGesture
}

public struct SpatialNavigationController: Sendable {
    public private(set) var activeSession: GestureSession?

    public init() {}

    @discardableResult
    public mutating func startGesture(triggerType: TriggerType) throws -> GestureSession {
        guard activeSession == nil else {
            throw NavigationControllerError.gestureAlreadyActive
        }

        let session = GestureSession(triggerType: triggerType)
        activeSession = session
        return session
    }

    @discardableResult
    public mutating func completeGesture(direction: Direction) throws -> GestureSession {
        guard var session = activeSession else {
            throw NavigationControllerError.noActiveGesture
        }

        _ = session.complete(direction: direction)
        activeSession = nil
        return session
    }

    @discardableResult
    public mutating func cancelGesture() throws -> GestureSession {
        guard var session = activeSession else {
            throw NavigationControllerError.noActiveGesture
        }

        _ = session.cancel()
        activeSession = nil
        return session
    }
}
