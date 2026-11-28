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
        XCTAssertEqual(
            evidence.captureExecutableIdentifier,
            "dev.gogolumo.Wheel.InputSpike"
        )
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

    func testRejectsRepeatedFieldsEvenWhenDecoderWouldChooseOne() {
        let json = String(decoding: validData(), as: UTF8.self)
            .replacingOccurrences(
                of: #""result": "pass""#,
                with: #""result": "failed", "result": "pass""#
            )

        XCTAssertThrowsError(
            try SignedBuildEvidence.decodeValidatedJSON(Data(json.utf8))
        ) { error in
            XCTAssertEqual(
                error as? SignedBuildEvidence.ValidationError,
                .repeatedFields
            )
        }
    }

    func testRejectsOversizedDocumentBeforeDecoding() {
        var data = validData()
        data.append(Data(repeating: 0x20, count: 4_096))

        XCTAssertThrowsError(
            try SignedBuildEvidence.decodeValidatedJSON(data)
        ) { error in
            XCTAssertEqual(
                error as? SignedBuildEvidence.ValidationError,
                .documentTooLarge
            )
        }
    }

    func testRejectsFailedOrForeignContract() {
        for replacement in [
            #""schemaVersion": 1"#,
            #""result": "failed""#,
            #""bundleIdentifier": "com.example.Foreign""#,
            #""backgroundApplication": false"#,
            #""signingTrust": "self-signed""#,
            #""captureExecutableIdentifier": "com.example.Foreign""#
        ] {
            let json = String(decoding: validData(), as: UTF8.self)
                .replacingOccurrences(of: contractFragment(for: replacement), with: replacement)

            XCTAssertThrowsError(
                try SignedBuildEvidence.decodeValidatedJSON(Data(json.utf8))
            )
        }
    }

    private func contractFragment(for replacement: String) -> String {
        if replacement.contains(#""schemaVersion""#) { return #""schemaVersion": 2"# }
        if replacement.contains(#""result""#) { return #""result": "pass""# }
        if replacement.contains(#""bundleIdentifier""#) {
            return #""bundleIdentifier": "dev.gogolumo.Wheel""#
        }
        if replacement.contains(#""backgroundApplication""#) {
            return #""backgroundApplication": true"#
        }
        if replacement.contains(#""captureExecutableIdentifier""#) {
            return #""captureExecutableIdentifier": "dev.gogolumo.Wheel.InputSpike""#
        }
        return #""signingTrust": "apple-generic""#
    }

    private func validData() -> Data {
        Data(
            #"""
            {
              "schemaVersion": 2,
              "result": "pass",
              "sourceRevision": "0123456789abcdef0123456789abcdef01234567",
              "bundleIdentifier": "dev.gogolumo.Wheel",
              "packageType": "APPL",
              "backgroundApplication": true,
              "brandResourceVersion": 1,
              "signingTrust": "apple-generic",
              "captureExecutableIdentifier": "dev.gogolumo.Wheel.InputSpike"
            }
            """#.utf8
        )
    }
}
