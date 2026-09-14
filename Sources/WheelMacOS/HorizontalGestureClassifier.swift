import WheelDomain

public struct PointerDisplacement: Equatable, Sendable {
    public let horizontal: Double
    public let vertical: Double

    public init(horizontal: Double, vertical: Double) {
        self.horizontal = horizontal
        self.vertical = vertical
    }
}

public struct HorizontalGestureClassifier: Sendable {
    public let minimumHorizontalDistance: Double
    public let minimumDominanceRatio: Double

    public init(
        minimumHorizontalDistance: Double = 80,
        minimumDominanceRatio: Double = 1.5
    ) {
        precondition(minimumHorizontalDistance > 0)
        precondition(minimumDominanceRatio >= 1)

        self.minimumHorizontalDistance = minimumHorizontalDistance
        self.minimumDominanceRatio = minimumDominanceRatio
    }

    public func classify(_ displacement: PointerDisplacement) -> Direction {
        let horizontalDistance = abs(displacement.horizontal)
        let verticalDistance = abs(displacement.vertical)

        guard horizontalDistance >= minimumHorizontalDistance else {
            return .none
        }

        guard horizontalDistance >= verticalDistance * minimumDominanceRatio else {
            return .none
        }

        return displacement.horizontal < 0 ? .left : .right
    }
}
