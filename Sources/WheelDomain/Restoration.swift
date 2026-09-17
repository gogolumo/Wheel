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

    /// Whether status and achieved depth describe the same restoration outcome.
    ///
    /// Successful and partial results must have verified a non-zero depth.
    /// All non-success outcomes must report `.none` so they cannot masquerade
    /// as a partially restored context.
    public var isValid: Bool {
        switch status {
        case .success, .partial:
            return depth != .none
        case .failed, .cancelled, .unavailable, .permissionDenied:
            return depth == .none
        }
    }

    public var allowsPositionChange: Bool {
        guard isValid else { return false }

        switch status {
        case .success, .partial:
            return true
        case .failed, .cancelled, .unavailable, .permissionDenied:
            return false
        }
    }
}
