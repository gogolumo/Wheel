import Foundation

public enum WheelGestureOverlayState: Equatable, Sendable {
    case hidden
    case triggerHeld
    case resultLeft
    case resultRight
    case resultNone

    public var isVisible: Bool {
        self != .hidden
    }
}

public enum WheelGestureOverlayFixture: String, CaseIterable, Sendable {
    case held
    case left
    case right
    case none

    public static func requested(from arguments: [String]) -> Self? {
        let option = "--overlay-fixture"

        if let argument = arguments.first(where: { $0.hasPrefix("\(option)=") }) {
            return Self(rawValue: String(argument.dropFirst("\(option)=".count)))
        }

        guard let index = arguments.firstIndex(of: option) else {
            return nil
        }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }

        return Self(rawValue: arguments[valueIndex])
    }

    public var state: WheelGestureOverlayState {
        switch self {
        case .held:
            return .triggerHeld
        case .left:
            return .resultLeft
        case .right:
            return .resultRight
        case .none:
            return .resultNone
        }
    }
}

public final class WheelOverlayScheduledAction {
    public private(set) var isCancelled = false

    private var cancellation: (() -> Void)?

    public init(cancellation: @escaping () -> Void = {}) {
        self.cancellation = cancellation
    }

    public func cancel() {
        guard !isCancelled else { return }

        isCancelled = true
        cancellation?()
        cancellation = nil
    }

    deinit {
        cancel()
    }
}

public struct WheelOverlayDismissScheduler {
    public typealias Schedule = (
        _ delay: TimeInterval,
        _ action: @escaping () -> Void
    ) -> WheelOverlayScheduledAction

    private let scheduleAction: Schedule

    public init(schedule: @escaping Schedule) {
        scheduleAction = schedule
    }

    public func schedule(
        after delay: TimeInterval,
        action: @escaping () -> Void
    ) -> WheelOverlayScheduledAction {
        scheduleAction(delay, action)
    }

    public static let mainQueue = WheelOverlayDismissScheduler { delay, action in
        let workItem = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: workItem
        )
        return WheelOverlayScheduledAction(cancellation: workItem.cancel)
    }
}
