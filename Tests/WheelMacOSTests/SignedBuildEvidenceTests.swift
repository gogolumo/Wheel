import Foundation
import XCTest
@testable import WheelMacOS

final class SignedBuildEvidenceTests: XCTestCase {
    func testDecodesExactPrivacySafeContract() throws {
        let evidence = try SignedBuildEvidence.decodeValidatedJSON(validData())

        XCTAssertEqual(
            evidence.sourceRevision,
            "0123456789abcdef0123456789abcdef01234567"
        )
        XCTAssertEqual(evidence.bundleIdentifier, "dev.gogolumo.Wheel")
        XCTAssertTrue(evidence.backgroundApplication)
    }

    func testRejectsUnexpectedFields() {
        let json = String(decoding: validData(), as: UTF8.self)
            .replacingOccurrences(
                of: #""signingTrust": "apple-generic""#,
                with: #""signingTrust": "apple-generic", "teamIdentifier": "PRIVATE""#
            )

        XCTAssertThrowsError(
            try SignedBuildEvidence.decodeValidatedJSON(Data(json.utf8))
        ) { error in
            XCTAssertEqual(
                error as? SignedBuildEvidence.ValidationError,
                .unsupportedFields
            )
        }
    }

    func testRejectsFailedOrForeignContract() {
        for replacement in [
            #""result": "failed""#,
            #""bundleIdentifier": "com.example.Foreign""#,
            #""backgroundApplication": false"#,
            #""signingTrust": "self-signed""#
        ] {
            let json = String(decoding: validData(), as: UTF8.self)
                .replacingOccurrences(of: contractFragment(for: replacement), with: replacement)

            XCTAssertThrowsError(
                try SignedBuildEvidence.decodeValidatedJSON(Data(json.utf8))
            )
        }
    }

    private func contractFragment(for replacement: String) -> String {
        if replacement.contains(#""result""#) { return #""result": "pass""# }
        if replacement.contains(#""bundleIdentifier""#) {
            return #""bundleIdentifier": "dev.gogolumo.Wheel""#
        }
        if replacement.contains(#""backgroundApplication""#) {
            return #""backgroundApplication": true"#
        }
        return #""signingTrust": "apple-generic""#
    }

    private func validData() -> Data {
        Data(
            #"""
            {
              "schemaVersion": 1,
              "result": "pass",
              "sourceRevision": "0123456789abcdef0123456789abcdef01234567",
              "bundleIdentifier": "dev.gogolumo.Wheel",
              "packageType": "APPL",
              "backgroundApplication": true,
              "brandResourceVersion": 1,
              "signingTrust": "apple-generic"
            }
            """#.utf8
        )
    }
}
