import Foundation

public enum WheelApplicationRunState: String, Codable, Equatable, Sendable {
    case running
    case terminated
    case unavailable
}

public struct WheelObservedApplication: Equatable, Sendable {
    public let localizedName: String
    public let bundleIdentifier: String?
    public let applicationURL: URL?
    public let processIdentifier: Int32

    public init(
        localizedName: String,
        bundleIdentifier: String?,
        applicationURL: URL?,
        processIdentifier: Int32
    ) {
        self.localizedName = localizedName
        self.bundleIdentifier = bundleIdentifier
        self.applicationURL = applicationURL
        self.processIdentifier = processIdentifier
    }

    public var stableIdentifier: String {
        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            return "bundle:\(bundleIdentifier)"
        }
        if let applicationURL {
            return "url:\(applicationURL.standardizedFileURL.path)"
        }
        return "name:\(localizedName)"
    }
}

public struct WheelApplicationContext: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let stableIdentifier: String
    public var localizedName: String
    public var bundleIdentifier: String?
    public var applicationURL: URL?
    public let firstSeenAt: Date
    public var lastActivatedAt: Date
    public var launchedAt: Date?
    public var terminatedAt: Date?
    public var runState: WheelApplicationRunState

    public init(
        id: UUID = UUID(),
        stableIdentifier: String,
        localizedName: String,
        bundleIdentifier: String?,
        applicationURL: URL?,
        firstSeenAt: Date,
        lastActivatedAt: Date,
        launchedAt: Date? = nil,
        terminatedAt: Date? = nil,
        runState: WheelApplicationRunState
    ) {
        self.id = id
        self.stableIdentifier = stableIdentifier
        self.localizedName = localizedName
        self.bundleIdentifier = bundleIdentifier
        self.applicationURL = applicationURL
        self.firstSeenAt = firstSeenAt
        self.lastActivatedAt = lastActivatedAt
        self.launchedAt = launchedAt
        self.terminatedAt = terminatedAt
        self.runState = runState
    }

    public init(
        observation: WheelObservedApplication,
        activatedAt: Date
    ) {
        self.init(
            stableIdentifier: observation.stableIdentifier,
            localizedName: observation.localizedName,
            bundleIdentifier: observation.bundleIdentifier,
            applicationURL: observation.applicationURL,
            firstSeenAt: activatedAt,
            lastActivatedAt: activatedAt,
            runState: .running
        )
    }
}
