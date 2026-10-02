import SwiftUI

/// Rounded annular wedge. Its center angle matches the existing input sector map.
struct WheelSectorShape: InsettableShape {
    let index: Int
    let count: Int
    var innerRadius: CGFloat = 100
    var outerInset: CGFloat = 12
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        guard count > 0 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = max(1, min(rect.width, rect.height) / 2 - outerInset - insetAmount)
        let inner = min(outer - 1, innerRadius + insetAmount)
        let angle = Double(index) / Double(count) * .pi * 2
        let halfAngle = Double.pi / Double(count) - 0.022
        let start = angle - halfAngle
        let end = angle + halfAngle
        let rounding: CGFloat = min(9, (outer - inner) / 4)
        let outerRound = Double(rounding / outer)
        let innerRound = Double(rounding / inner)

        func point(_ radius: CGFloat, _ angle: Double) -> CGPoint {
            CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
        }

        var path = Path()
        path.move(to: point(outer, start + outerRound))
        path.addArc(
            center: center, radius: outer,
            startAngle: .radians(start + outerRound),
            endAngle: .radians(end - outerRound), clockwise: false
        )
        path.addQuadCurve(
            to: point(outer - rounding, end), control: point(outer, end)
        )
        path.addLine(to: point(inner + rounding, end))
        path.addQuadCurve(
            to: point(inner, end - innerRound), control: point(inner, end)
        )
        path.addArc(
            center: center, radius: inner,
            startAngle: .radians(end - innerRound),
            endAngle: .radians(start + innerRound), clockwise: true
        )
        path.addQuadCurve(
            to: point(inner + rounding, start), control: point(inner, start)
        )
        path.addLine(to: point(outer - rounding, start))
        path.addQuadCurve(
            to: point(outer, start + outerRound), control: point(outer, start)
        )
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> Self {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}
