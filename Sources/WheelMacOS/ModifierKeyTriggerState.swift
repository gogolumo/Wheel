enum ModifierKeyTriggerEdge: Equatable, Sendable {
    case pressed
    case released
}

/// Tracks the press/release pair for one modifier key from `flagsChanged`
/// events.
///
/// Core Graphics exposes aggregate modifier flags, not a reliable per-key
/// polling state for every modifier. The matching key code identifies the
/// selected physical modifier. The aggregate flag is used to reject a stray
/// release when monitoring starts while the key is already held; after a
/// press, the next matching signal is its release even if the equivalent
/// modifier on the other side of the keyboard remains held.
struct ModifierKeyTriggerState: Sendable {
    let keyCode: Int64

    private(set) var isPressed = false

    func matches(_ eventKeyCode: Int64) -> Bool {
        eventKeyCode == keyCode
    }

    mutating func consume(
        eventKeyCode: Int64,
        modifierFlagEnabled: Bool
    ) -> ModifierKeyTriggerEdge? {
        guard matches(eventKeyCode) else {
            return nil
        }

        if isPressed {
            isPressed = false
            return .released
        }

        guard modifierFlagEnabled else {
            return nil
        }

        isPressed = true
        return .pressed
    }

    mutating func reset() {
        isPressed = false
    }
}
