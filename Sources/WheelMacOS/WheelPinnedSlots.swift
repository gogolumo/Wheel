import Combine
import Foundation

public struct WheelPinnedApplication: Codable, Equatable, Sendable {
    public let stableIdentifier: String
    public let localizedName: String
    public let bundleIdentifier: String?
    public let applicationURL: URL?

    public init(
        stableIdentifier: String,
        localizedName: String,
        bundleIdentifier: String?,
        applicationURL: URL?
    ) {
        self.stableIdentifier = stableIdentifier
        self.localizedName = localizedName
        self.bundleIdentifier = bundleIdentifier
        self.applicationURL = applicationURL
    }

    public init(context: WheelApplicationContext) {
        self.init(
            stableIdentifier: context.stableIdentifier,
            localizedName: context.localizedName,
            bundleIdentifier: context.bundleIdentifier,
            applicationURL: context.applicationURL
        )
    }
}

public struct WheelPinnedSlot: Codable, Equatable, Identifiable, Sendable {
    public let position: Int
    public var application: WheelPinnedApplication
    public var id: Int { position }

    public init(position: Int, application: WheelPinnedApplication) {
        self.position = position
        self.application = application
    }
}

@MainActor
public final class WheelPinnedSlotStore: ObservableObject {
    @Published public private(set) var slots: [WheelPinnedSlot]

    private static let key = "wheel.pinnedSlots.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([WheelPinnedSlot].self, from: data) {
            slots = decoded.sorted { $0.position < $1.position }
        } else {
            slots = []
        }
    }

    public func pin(_ application: WheelPinnedApplication, at position: Int) {
        guard position >= 0 else { return }
        slots.removeAll { $0.position == position || $0.application.stableIdentifier == application.stableIdentifier }
        slots.append(.init(position: position, application: application))
        slots.sort { $0.position < $1.position }
        persist()
    }

    public func unpin(position: Int) {
        slots.removeAll { $0.position == position }
        persist()
    }

    public func application(at position: Int) -> WheelPinnedApplication? {
        slots.first { $0.position == position }?.application
    }

    /// Pins outside the currently visible direction count are retained rather than destroyed.
    public func visibleSlots(directionCount: Int) -> [WheelPinnedSlot] {
        slots.filter { $0.position < directionCount }
    }

    public func merge(dynamic contexts: [WheelApplicationContext], directionCount: Int) -> [WheelApplicationContext?] {
        guard directionCount > 0 else { return [] }
        var result = Array<WheelApplicationContext?>(repeating: nil, count: directionCount)
        let visiblePins = visibleSlots(directionCount: directionCount)
        let pinnedIDs = Set(visiblePins.map(\.application.stableIdentifier))

        for slot in visiblePins {
            let app = slot.application
            if let live = contexts.first(where: { $0.stableIdentifier == app.stableIdentifier }) {
                result[slot.position] = live
            } else {
                result[slot.position] = WheelApplicationContext(
                    stableIdentifier: app.stableIdentifier,
                    localizedName: app.localizedName,
                    bundleIdentifier: app.bundleIdentifier,
                    applicationURL: app.applicationURL,
                    firstSeenAt: .distantPast,
                    lastActivatedAt: .distantPast,
                    runState: app.applicationURL == nil ? .unavailable : .terminated
                )
            }
        }

        var dynamic = contexts.filter { !pinnedIDs.contains($0.stableIdentifier) }.makeIterator()
        for index in result.indices where result[index] == nil {
            result[index] = dynamic.next()
        }
        return result
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(slots) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
