import AppKit
import SwiftUI
import WheelDomain
import WheelMacOS

struct WheelStatusLabel: View {
    let status: WheelAppStatus
    var isGestureActive = false

    var body: some View {
        Label(
            isGestureActive ? "Trigger Held" : status.rawValue,
            systemImage: isGestureActive ? "cursorarrow.motionlines" : status.symbolName
        )
        .font(.caption.weight(.medium))
        .foregroundStyle(isGestureActive ? Color.primary : status.tint)
        .accessibilityLabel(
            "Wheel status: \(isGestureActive ? "Trigger Held" : status.rawValue)"
        )
    }
}

struct WheelMark: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "arrow.left.arrow.right")
            .font(.system(size: size * 0.4, weight: .medium))
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
            .background {
                WheelGlassSurface(shape: Circle(), role: .control)
            }
            .accessibilityHidden(true)
    }
}

@MainActor
enum WheelSystemSettings {
    static func openInputMonitoring() {
        if let privacyURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        ), NSWorkspace.shared.open(privacyURL) {
            return
        }

        NSWorkspace.shared.open(
            URL(fileURLWithPath: "/System/Applications/System Settings.app")
        )
    }
}

extension WheelAppStatus {
    var symbolName: String {
        switch self {
        case .starting: return "hourglass"
        case .disabled: return "power"
        case .needsPermission: return "exclamationmark.shield"
        case .ready: return "checkmark.circle"
        case .paused: return "pause.circle"
        case .error: return "exclamationmark.octagon"
        }
    }

    var menuBarSymbolName: String {
        switch self {
        case .ready: return "arrow.left.arrow.right.circle.fill"
        case .starting: return "arrow.left.arrow.right.circle"
        case .disabled: return "circle.slash"
        case .needsPermission: return "exclamationmark.triangle"
        case .paused: return "pause.circle"
        case .error: return "xmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .starting, .disabled, .paused: return .secondary
        case .needsPermission: return .orange
        case .ready: return .primary
        case .error: return .red
        }
    }
}

extension TriggerType {
    var productName: String {
        switch self {
        case .rightOption: return "Right Option"
        case .capsLock: return "Caps Lock"
        case .mouseSideButton: return "Mouse Side Button"
        }
    }

    var keycapLabel: String {
        switch self {
        case .rightOption: return "Right ⌥"
        case .capsLock: return "⇪ Caps Lock"
        case .mouseSideButton: return "Mouse 4"
        }
    }
}
