import Foundation

/// Privacy-safe attestation emitted only after the signed SPIKE-001 bundle
/// verifier completes. Certificate, account, path, and hardware data are
/// deliberately absent from this schema.
public struct SignedBuildEvidence: Codable, Equatable, Sendable {
    public enum ValidationError: Error, Equatable, Sendable {
        case documentTooLarge
        case topLevelObjectRequired
        case repeatedFields
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
        guard data.count <= 4_096 else {
            throw ValidationError.documentTooLarge
        }
        guard let source = String(data: data, encoding: .utf8) else {
            throw ValidationError.topLevelObjectRequired
        }
        let object = try JSONSerialization.jsonObject(with: data)
        guard let fields = object as? [String: Any] else {
            throw ValidationError.topLevelObjectRequired
        }
        guard Set(fields.keys) == Set(CodingKeys.allCases.map(\.rawValue)) else {
            throw ValidationError.unsupportedFields
        }
        guard CodingKeys.allCases.allSatisfy({
            source.components(separatedBy: "\"\($0.rawValue)\"").count == 2
        }) else {
            throw ValidationError.repeatedFields
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
