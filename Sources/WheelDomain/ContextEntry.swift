import Foundation

public struct ContextEntry: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let applicationBundleID: String
    public let contextToken: String?
    public let capturedAt: Date

    public init(
        id: UUID = UUID(),
        applicationBundleID: String,
        contextToken: String? = nil,
        capturedAt: Date = Date()
    ) {
        self.id = id
        self.applicationBundleID = applicationBundleID
        self.contextToken = contextToken
        self.capturedAt = capturedAt
    }

    /// Privacy-minimal identity used by the pure history layer.
    /// Native capture code is responsible for ensuring the token itself is safe to store.
    public var semanticKey: SemanticKey {
        SemanticKey(
            applicationBundleID: applicationBundleID,
            contextToken: contextToken
        )
    }

    public struct SemanticKey: Equatable, Hashable, Sendable {
        public let applicationBundleID: String
        public let contextToken: String?

        public init(applicationBundleID: String, contextToken: String?) {
            self.applicationBundleID = applicationBundleID
            self.contextToken = contextToken
        }
    }
}
