import SwiftUI

/// Presentation tokens shared by the native shell and transient gesture surfaces.
enum WheelVisualTokens {
    enum Spacing {
        static let xs: CGFloat = 4
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let regular: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let section: CGFloat = 32
    }

    enum Radius {
        static let tiny: CGFloat = 8
        static let control: CGFloat = 12
        static let context: CGFloat = 16
        static let card: CGFloat = 20
        static let panel: CGFloat = 24
        static let floating: CGFloat = 28
    }

    enum Motion {
        static let entrance = Animation.easeOut(duration: 0.16)
        static let selection = Animation.easeOut(duration: 0.11)
        static let selectedScale: CGFloat = 1.045
        static let selectedOffset: CGFloat = 4
    }

    enum Optical {
        // Optical lighting uses white and black intentionally; content uses semantic colors.
        static let highlight = Color.white
        static let shadow = Color.black
        static let coolEdge = Color(red: 0.62, green: 0.73, blue: 0.88)
        static let violetEdge = Color(red: 0.75, green: 0.71, blue: 0.88)
        static let selectedWash = coolEdge.opacity(0.16)
        static let restingWash = Color.primary.opacity(0.025)
        static let resultRecession = 0.76

        static func rim(dark: Bool, emphasized: Bool = false) -> LinearGradient {
            LinearGradient(
                colors: [
                    highlight.opacity(emphasized ? 0.88 : (dark ? 0.52 : 0.76)),
                    coolEdge.opacity(emphasized ? 0.65 : 0.20),
                    highlight.opacity(dark ? 0.14 : 0.32),
                    violetEdge.opacity(emphasized ? 0.48 : 0.16),
                    highlight.opacity(dark ? 0.40 : 0.60)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

enum WheelSurfaceRole {
    case overlay, context, navigation, popover, control, selected, panel

    var material: Material {
        switch self {
        case .overlay, .navigation, .control: return .thinMaterial
        case .context, .popover, .selected, .panel: return .regularMaterial
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .overlay: return 18
        case .context, .popover, .panel: return 12
        case .navigation, .control, .selected: return 4
        }
    }
}
