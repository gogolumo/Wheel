import Combine
import Foundation

public struct WheelApplicationHistorySnapshot: Codable, Equatable, Sendable {
    public var entries: [WheelApplicationContext]
    public var currentIdentifier: String?

    public init(
        entries: [WheelApplicationContext],
        currentIdentifier: String?
    ) {
        self.entries = entries
        self.currentIdentifier = currentIdentifier
    }
}

public protocol WheelApplicationHistoryPersisting: AnyObject {
    func load() -> WheelApplicationHistorySnapshot?
    func save(_ snapshot: WheelApplicationHistorySnapshot)
}

public final class WheelJSONApplicationHistoryPersistence:
    WheelApplicationHistoryPersisting
{
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() -> WheelApplicationHistorySnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return try? decoder.decode(
            WheelApplicationHistorySnapshot.self,
            from: data
        )
    }

    public func save(_ snapshot: WheelApplicationHistorySnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }

        let directory = fileURL.deletingLastPathComponent()
        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let base = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)

        return base
            .appendingPathComponent("Wheel", isDirectory: true)
            .appendingPathComponent("application-history.json")
    }
}

@MainActor
public final class WheelApplicationHistoryStore: ObservableObject {
    @Published public private(set) var entries: [WheelApplicationContext]
    @Published public private(set) var currentIdentifier: String?

    private let persistence: any WheelApplicationHistoryPersisting

    public init(
        persistence: any WheelApplicationHistoryPersisting =
            WheelJSONApplicationHistoryPersistence()
    ) {
        self.persistence = persistence
        let snapshot = persistence.load()
        entries = snapshot?.entries ?? []
        currentIdentifier = snapshot?.currentIdentifier
    }

    public func recordActivation(
        _ observation: WheelObservedApplication,
        at date: Date = Date(),
        capacity: Int
    ) {
        let capacity = max(1, capacity)
        let identifier = observation.stableIdentifier

        if currentIdentifier == identifier, let index = entries.firstIndex(
            where: { $0.stableIdentifier == identifier }
        ) {
            entries[index].localizedName = observation.localizedName
            entries[index].bundleIdentifier = observation.bundleIdentifier
            entries[index].applicationURL = observation.applicationURL
            entries[index].lastActivatedAt = date
            entries[index].runState = .running
            entries[index].terminatedAt = nil
            persist()
            return
        }

        entries.insert(
            WheelApplicationContext(
                observation: observation,
                activatedAt: date
            ),
            at: 0
        )
        currentIdentifier = identifier

        if entries.count > capacity {
            entries.removeLast(entries.count - capacity)
        }

        markMatchingEntries(
            identifier: identifier,
            state: .running,
            terminatedAt: nil,
            keepingNewestActivation: true
        )
        persist()
    }

    public func recordLaunch(
        _ observation: WheelObservedApplication,
        at date: Date = Date()
    ) {
        let identifier = observation.stableIdentifier
        var changed = false

        for index in entries.indices where entries[index].stableIdentifier == identifier {
            entries[index].localizedName = observation.localizedName
            entries[index].bundleIdentifier = observation.bundleIdentifier
            entries[index].applicationURL = observation.applicationURL
            entries[index].launchedAt = date
            entries[index].terminatedAt = nil
            entries[index].runState = .running
            changed = true
        }

        if changed {
            persist()
        }
    }

    public func recordTermination(
        _ observation: WheelObservedApplication,
        at date: Date = Date(),
        rememberClosedApplications: Bool
    ) {
        let identifier = observation.stableIdentifier

        if rememberClosedApplications {
            var changed = false
            for index in entries.indices where entries[index].stableIdentifier == identifier {
                entries[index].terminatedAt = date
                entries[index].runState = .terminated
                changed = true
            }
            if changed {
                persist()
            }
        } else {
            entries.removeAll { $0.stableIdentifier == identifier }
            if currentIdentifier == identifier {
                currentIdentifier = entries.first?.stableIdentifier
            }
            persist()
        }
    }

    public func markUnavailable(_ context: WheelApplicationContext) {
        var changed = false
        for index in entries.indices where entries[index].stableIdentifier == context.stableIdentifier {
            entries[index].runState = .unavailable
            changed = true
        }
        if changed {
            persist()
        }
    }

    public func wheelEntries(limit: Int) -> [WheelApplicationContext] {
        guard limit > 0 else { return [] }

        var seen = Set<String>()
        var result: [WheelApplicationContext] = []

        for entry in entries {
            if entry.stableIdentifier == currentIdentifier {
                continue
            }
            guard seen.insert(entry.stableIdentifier).inserted else {
                continue
            }
            result.append(entry)
            if result.count == limit {
                break
            }
        }

        return result
    }

    private func markMatchingEntries(
        identifier: String,
        state: WheelApplicationRunState,
        terminatedAt: Date?,
        keepingNewestActivation: Bool
    ) {
        var skippedNewest = false
        for index in entries.indices where entries[index].stableIdentifier == identifier {
            if keepingNewestActivation && !skippedNewest {
                skippedNewest = true
            }
            entries[index].runState = state
            entries[index].terminatedAt = terminatedAt
        }
    }

    private func persist() {
        persistence.save(
            .init(
                entries: entries,
                currentIdentifier: currentIdentifier
            )
        )
    }
}
