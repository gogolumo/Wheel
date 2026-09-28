import Combine
import Foundation

@MainActor
public final class WheelSettings: ObservableObject {
    public static let supportedDirectionCounts = [2, 4, 6, 8, 10, 12]
    public static let visibleItemRange = 3...12
    public static let historyCapacityRange = 10...200

    @Published public private(set) var visibleItemCount: Int
    @Published public private(set) var directionCount: Int
    @Published public private(set) var historyCapacity: Int
    @Published public private(set) var rememberClosedApplications: Bool

    private enum Key {
        static let visibleItemCount = "wheel.visibleItemCount"
        static let directionCount = "wheel.directionCount"
        static let historyCapacity = "wheel.historyCapacity"
        static let rememberClosedApplications = "wheel.rememberClosedApplications"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedVisible = defaults.object(forKey: Key.visibleItemCount) as? Int
        visibleItemCount = Self.clamp(
            storedVisible ?? 8,
            to: Self.visibleItemRange
        )

        let storedDirection = defaults.object(forKey: Key.directionCount) as? Int
        let requestedDirection = storedDirection ?? 8
        directionCount = Self.supportedDirectionCounts.contains(requestedDirection)
            ? requestedDirection
            : 8

        let storedCapacity = defaults.object(forKey: Key.historyCapacity) as? Int
        historyCapacity = Self.clamp(
            storedCapacity ?? 50,
            to: Self.historyCapacityRange
        )

        if defaults.object(forKey: Key.rememberClosedApplications) == nil {
            rememberClosedApplications = true
        } else {
            rememberClosedApplications = defaults.bool(
                forKey: Key.rememberClosedApplications
            )
        }
    }

    public func setVisibleItemCount(_ value: Int) {
        let value = Self.clamp(value, to: Self.visibleItemRange)
        guard value != visibleItemCount else { return }

        visibleItemCount = value
        defaults.set(value, forKey: Key.visibleItemCount)
    }

    public func setDirectionCount(_ value: Int) {
        guard Self.supportedDirectionCounts.contains(value),
              value != directionCount
        else {
            return
        }

        directionCount = value
        defaults.set(value, forKey: Key.directionCount)
    }

    public func setHistoryCapacity(_ value: Int) {
        let value = Self.clamp(value, to: Self.historyCapacityRange)
        guard value != historyCapacity else { return }

        historyCapacity = value
        defaults.set(value, forKey: Key.historyCapacity)
    }

    public func setRememberClosedApplications(_ value: Bool) {
        guard value != rememberClosedApplications else { return }

        rememberClosedApplications = value
        defaults.set(value, forKey: Key.rememberClosedApplications)
    }

    private static func clamp(
        _ value: Int,
        to range: ClosedRange<Int>
    ) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
