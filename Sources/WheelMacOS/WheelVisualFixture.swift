import Foundation

/// Synthetic presentation data, available only through an explicit launch option.
/// None of these identities represent an observed or restorable user application.
public enum WheelVisualFixture: String, CaseIterable, Sendable {
    case empty
    case two
    case four
    case six
    case eight
    case twelve
    case selectedRunning = "selected-running"
    case selectedTerminated = "selected-terminated"
    case unavailablePin = "unavailable-pin"
    case mixedPins = "mixed-pins"

    public static func requested(from arguments: [String]) -> Self? {
        let option = "--visual-fixture"
        if let argument = arguments.first(where: { $0.hasPrefix("\(option)=") }) {
            return Self(rawValue: String(argument.dropFirst("\(option)=".count)))
        }

        guard let index = arguments.firstIndex(of: option) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return Self(rawValue: arguments[valueIndex])
    }

    var directionCount: Int {
        switch self {
        case .two: return 2
        case .four: return 4
        case .six, .selectedRunning, .selectedTerminated, .unavailablePin: return 6
        case .empty, .eight, .mixedPins: return 8
        case .twelve: return 12
        }
    }

    var overlayState: WheelGestureOverlayState {
        switch self {
        case .selectedRunning, .selectedTerminated: return .resultSelection
        default: return .triggerHeld
        }
    }

    var selectedIndex: Int? {
        overlayState == .resultSelection ? 0 : nil
    }

    var hoveredIndex: Int? {
        switch self {
        case .selectedRunning, .selectedTerminated: return 0
        case .unavailablePin: return 2
        case .mixedPins: return 1
        default: return nil
        }
    }

    var historySnapshot: WheelApplicationHistorySnapshot {
        let count = self == .empty ? 0 : (self == .unavailablePin ? 5 : directionCount)
        let contexts = (0..<count).map { index in
            Self.context(
                at: index,
                state: (self == .selectedTerminated && index == 0)
                    || (self == .mixedPins && index == 5)
                    ? .terminated : .running
            )
        }
        // No current app: every supplied synthetic context is visible in the wheel.
        return .init(entries: contexts, currentIdentifier: nil)
    }

    var pins: [WheelPinnedSlot] {
        switch self {
        case .unavailablePin:
            return [.init(
                position: 2,
                application: .init(context: Self.context(at: 12, state: .unavailable))
            )]
        case .mixedPins:
            return [
                .init(position: 1, application: .init(context: Self.context(at: 1, state: .running))),
                .init(position: 5, application: .init(context: Self.context(at: 5, state: .terminated)))
            ]
        default:
            return []
        }
    }

    func context(for pinned: WheelPinnedApplication) -> WheelApplicationContext? {
        if self == .unavailablePin {
            let missing = Self.context(at: 12, state: .unavailable)
            if missing.stableIdentifier == pinned.stableIdentifier {
                return missing
            }
        }
        return historySnapshot.entries.first {
            $0.stableIdentifier == pinned.stableIdentifier
        }
    }

    private static func context(
        at index: Int,
        state: WheelApplicationRunState
    ) -> WheelApplicationContext {
        let names = [
            "Sample Browser", "Sample Editor", "Sample Files", "Sample Mail",
            "Sample Calendar", "Sample Notes", "Sample Music", "Sample Photos",
            "Sample Terminal", "Sample Messages", "Sample Tasks", "Sample Document",
            "Sample Missing App"
        ]
        let date = Date(timeIntervalSince1970: 1_704_067_200 + Double(index * 60))
        return WheelApplicationContext(
            id: UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", index + 1))")!,
            stableIdentifier: "fixture:application.\(index)",
            localizedName: names[index],
            bundleIdentifier: nil,
            applicationURL: nil,
            firstSeenAt: date,
            lastActivatedAt: date,
            terminatedAt: state == .terminated ? date.addingTimeInterval(30) : nil,
            runState: state
        )
    }
}

/// The normal settings/pins stores can be reused without consulting any user
/// defaults domain or writing synthetic settings to disk.
final class WheelFixtureUserDefaults: UserDefaults {
    private var values: [String: Any] = [:]

    init() {
        super.init(suiteName: "Wheel.Fixture.\(UUID().uuidString)")!
    }

    override func object(forKey defaultName: String) -> Any? {
        values[defaultName]
    }

    override func data(forKey defaultName: String) -> Data? {
        values[defaultName] as? Data
    }

    override func bool(forKey defaultName: String) -> Bool {
        values[defaultName] as? Bool ?? false
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }

    override func removeObject(forKey defaultName: String) {
        values.removeValue(forKey: defaultName)
    }
}

final class WheelFixtureHistoryPersistence: WheelApplicationHistoryPersisting {
    private var snapshot: WheelApplicationHistorySnapshot?

    init(snapshot: WheelApplicationHistorySnapshot? = nil) {
        self.snapshot = snapshot
    }

    func load() -> WheelApplicationHistorySnapshot? {
        snapshot
    }

    func save(_ snapshot: WheelApplicationHistorySnapshot) {
        self.snapshot = snapshot
    }
}
