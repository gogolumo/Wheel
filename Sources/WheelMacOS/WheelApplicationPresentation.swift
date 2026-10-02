import Foundation

/// Read-only presentation state. It does not decide selection or perform restoration.
public struct WheelApplicationPresentation: Equatable, Sendable {
    public let runState: WheelApplicationRunState
    public let isPinned: Bool

    public init(runState: WheelApplicationRunState, isPinned: Bool) {
        self.runState = runState
        self.isPinned = isPinned
    }

    public var statusText: String {
        switch runState {
        case .running: return "Running"
        case .terminated: return "Recently closed"
        case .unavailable: return "Unavailable"
        }
    }

    public var symbolName: String {
        switch runState {
        case .running: return "circle.fill"
        case .terminated: return "arrow.clockwise"
        case .unavailable: return "slash.circle"
        }
    }

    /// An unavailable persistent pin must never promise a working open action.
    public var releaseInstruction: String? {
        switch runState {
        case .running: return "Release to switch"
        case .terminated: return "Release to reopen"
        case .unavailable: return nil
        }
    }

    public var accessibilityState: String {
        isPinned ? "\(statusText), pinned" : statusText
    }
}
