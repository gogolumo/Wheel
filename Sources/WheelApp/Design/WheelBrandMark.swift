import SwiftUI

/// The production vector symbol, without the app icon's rounded-square container.
struct WheelBrandMark: View {
    enum Variant {
        case adaptive, color, light, dark, monochrome
    }

    let size: CGFloat
    var variant: Variant = .adaptive

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if variant == .monochrome {
                Image(nsImage: WheelBrand.menuBarTemplateImage)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(WheelBrand.primaryForeground)
            } else if let image = useLightVariant ? WheelBrand.lightSymbol : WheelBrand.colorSymbol {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.original)
            } else {
                WheelRadialContextFallback()
                    .fill(WheelBrand.gradient)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var useLightVariant: Bool {
        variant == .light || (variant == .adaptive && colorScheme == .light)
    }
}

/// Resource-failure fallback only. Geometry follows the master: four equal gaps,
/// a 48/26.2 annulus, and a 13.4 central core on a 100-point coordinate system.
struct WheelRadialContextFallback: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 100
        guard scale > 0 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer: CGFloat = 48 * scale
        let inner: CGFloat = 26.2 * scale
        let rounding: CGFloat = 7 * scale
        let outerRound = Double(rounding / outer)
        let innerRound = Double(rounding / inner)

        func point(_ radius: CGFloat, _ angle: Double) -> CGPoint {
            CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
        }

        var path = Path()
        for index in 0..<4 {
            let start = Double(index) * .pi / 2 + 8 * .pi / 180
            let end = Double(index) * .pi / 2 + 82 * .pi / 180
            path.move(to: point(outer, start + outerRound))
            path.addArc(
                center: center, radius: outer,
                startAngle: .radians(start + outerRound),
                endAngle: .radians(end - outerRound), clockwise: false
            )
            path.addQuadCurve(to: point(outer - rounding, end), control: point(outer, end))
            path.addLine(to: point(inner + rounding, end))
            path.addQuadCurve(to: point(inner, end - innerRound), control: point(inner, end))
            path.addArc(
                center: center, radius: inner,
                startAngle: .radians(end - innerRound),
                endAngle: .radians(start + innerRound), clockwise: true
            )
            path.addQuadCurve(to: point(inner + rounding, start), control: point(inner, start))
            path.addLine(to: point(outer - rounding, start))
            path.addQuadCurve(to: point(outer, start + outerRound), control: point(outer, start))
            path.closeSubpath()
        }
        let core = 13.4 * scale
        path.addEllipse(in: CGRect(x: center.x - core, y: center.y - core, width: core * 2, height: core * 2))
        return path
    }
}
