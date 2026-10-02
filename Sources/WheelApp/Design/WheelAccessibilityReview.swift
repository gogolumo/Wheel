import SwiftUI

/// Additive fixture-only accessibility policy. System preferences always win:
/// review exports can enable a fallback, but can never disable a user's preference.
struct WheelAccessibilityReview {
    var reduceMotion = false
    var reduceTransparency = false
    var differentiateWithoutColor = false
    var increaseContrast = false
}

private struct WheelAccessibilityReviewKey: EnvironmentKey {
    static let defaultValue: WheelAccessibilityReview? = nil
}

extension EnvironmentValues {
    var wheelAccessibilityReview: WheelAccessibilityReview? {
        get { self[WheelAccessibilityReviewKey.self] }
        set { self[WheelAccessibilityReviewKey.self] = newValue }
    }
}
