import Foundation

/// Privacy-safe attestation emitted only after the signed SPIKE-001 bundle
/// verifier completes. Certificate, account, path, and hardware data are
/// deliberately absent from this schema.
public struct SignedBuildEvidence: Codable, Equatable, Sendable {
    public enum ValidationError: Error, Equatable, Sendable {
        case topLevelObjectRequired
        case unsupportedFields
        case invalidContract
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case result
        case sourceRevision
        case bundleIdentifier
        case packageType
        case backgroundApplication
        case brandResourceVersion
        case signingTrust
    }

    public let schemaVersion: Int
    public let result: String
    public let sourceRevision: String
    public let bundleIdentifier: String
    public let packageType: String
    public let backgroundApplication: Bool
    public let brandResourceVersion: Int
    public let signingTrust: String

    public static func decodeValidatedJSON(_ data: Data) throws -> Self {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let fields = object as? [String: Any] else {
            throw ValidationError.topLevelObjectRequired
        }
        guard Set(fields.keys) == Set(CodingKeys.allCases.map(\.rawValue)) else {
            throw ValidationError.unsupportedFields
        }

        let evidence = try JSONDecoder().decode(Self.self, from: data)
        guard
            evidence.schemaVersion == 1,
            evidence.result == "pass",
            evidence.sourceRevision.range(
                of: "^[0-9a-f]{40}$",
                options: .regularExpression
            ) != nil,
            evidence.bundleIdentifier == "dev.gogolumo.Wheel",
            evidence.packageType == "APPL",
            evidence.backgroundApplication,
            evidence.brandResourceVersion == 1,
            evidence.signingTrust == "apple-generic"
        else {
            throw ValidationError.invalidContract
        }
        return evidence
    }
}
