import XCTest
@testable import WheelMacOS

final class InputEvidenceRunLabelTests: XCTestCase {
    func testAcceptsBoundedSingleLineEvidenceLabels() {
        XCTAssertNil(InputEvidenceRunLabel.validationError(for: "right-option Finder_01"))
        XCTAssertNil(
            InputEvidenceRunLabel.validationError(
                for: String(repeating: "a", count: InputEvidenceRunLabel.maximumLength)
            )
        )
    }

    func testRejectsEmptyPaddedAndOversizedLabels() {
        XCTAssertNotNil(InputEvidenceRunLabel.validationError(for: ""))
        XCTAssertNotNil(InputEvidenceRunLabel.validationError(for: " padded"))
        XCTAssertNotNil(InputEvidenceRunLabel.validationError(for: "padded "))
        XCTAssertNotNil(
            InputEvidenceRunLabel.validationError(
                for: String(repeating: "a", count: InputEvidenceRunLabel.maximumLength + 1)
            )
        )
    }

    func testRejectsMultilinePathAndURLLikeLabels() {
        XCTAssertNotNil(InputEvidenceRunLabel.validationError(for: "run\nforged-field"))
        XCTAssertNotNil(InputEvidenceRunLabel.validationError(for: "private/user/path"))
        XCTAssertNotNil(InputEvidenceRunLabel.validationError(for: "https://example.com"))
    }
}
