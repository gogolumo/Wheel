public enum RestorationStatus: String, Equatable, Sendable {
    case success
    case partial
    case failed
    case cancelled
    case unavailable
    case permissionDenied
}

public enum RestorationDepth: Int, Comparable, Sendable {
    case none = 0
    case application = 1
    case window = 2
    case semantic = 3

    public static func < (lhs: RestorationDepth, rhs: RestorationDepth) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct RestorationResult: Equatable, Sendable {
    public let status: RestorationStatus
    public let depth: RestorationDepth

    public init(status: RestorationStatus, depth: RestorationDepth) {
        self.status = status
        self.depth = depth
    }

    public var allowsPositionChange: Bool {
        switch status {
        case .success, .partial:
            return true
        case .failed, .cancelled, .unavailable, .permissionDenied:
            return false
        }
    }
}
