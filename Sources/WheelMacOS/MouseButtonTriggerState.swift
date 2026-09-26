enum MouseButtonTriggerEdge: Equatable, Sendable {
    case pressed
    case released
}

/// Pure edge detector for a configured auxiliary mouse button.
///
/// Mouse drivers may emit repeated down events or a release without a matching
/// press. Keeping that state outside `CGEvent` handling makes the behavior
/// deterministic and prevents duplicate gesture sessions.
struct MouseButtonTriggerState: Sendable {
    let buttonNumber: Int64

    private(set) var isPressed = false

    init(buttonNumber: Int64) {
        precondition(buttonNumber >= 3, "A side button number must be 3 or greater.")
        self.buttonNumber = buttonNumber
    }

    func matches(_ eventButtonNumber: Int64) -> Bool {
        eventButtonNumber == buttonNumber
    }

    mutating func consume(
        eventButtonNumber: Int64,
        isDown: Bool
    ) -> MouseButtonTriggerEdge? {
        guard matches(eventButtonNumber) else {
            return nil
        }

        switch (isPressed, isDown) {
        case (false, true):
            isPressed = true
            return .pressed
        case (true, false):
            isPressed = false
            return .released
        case (false, false), (true, true):
            return nil
        }
    }

    mutating func reset() {
        isPressed = false
    }
}
