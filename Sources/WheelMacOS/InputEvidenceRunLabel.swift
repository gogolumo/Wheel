import Foundation

/// Validates the operator-supplied label persisted in aggregate spike evidence.
///
/// A restricted, bounded label keeps evidence filenames and terminal output
/// single-line and discourages accidental paths, URLs, or structured content.
public enum InputEvidenceRunLabel {
    public static let maximumLength = 64

    public static func validationError(for label: String) -> String? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Run label is required."
        }
        guard trimmed == label, label.count <= maximumLength else {
            return "Use a 1–64 character label without leading or trailing spaces."
        }

        let allowedPunctuation = CharacterSet(charactersIn: "-_ ")
        let allowedCharacters = CharacterSet.alphanumerics.union(allowedPunctuation)
        guard label.unicodeScalars.allSatisfy(allowedCharacters.contains) else {
            return "Use only letters, numbers, spaces, hyphens, and underscores in the label."
        }

        return nil
    }
}
