import Darwin
import Foundation
import WheelDomain
import WheelMacOS

private struct Arguments {
    var triggerType: TriggerType = .capsLock
    var minimumDistance = 80.0
    var dominanceRatio = 1.5
    var sequenceTarget = 100
    var runLabel = "unlabelled"

    init(_ rawArguments: ArraySlice<String>) throws {
        var index = rawArguments.startIndex

        while index < rawArguments.endIndex {
            let argument = rawArguments[index]

            switch argument {
            case "--trigger":
                index = rawArguments.index(after: index)
                guard index < rawArguments.endIndex else {
                    throw ArgumentError.missingValue("--trigger")
                }
                triggerType = try Self.parseTrigger(rawArguments[index])
            case "--distance":
                index = rawArguments.index(after: index)
                guard
                    index < rawArguments.endIndex,
                    let value = Double(rawArguments[index]),
                    value > 0
                else {
                    throw ArgumentError.invalidValue("--distance")
                }
                minimumDistance = value
            case "--dominance":
                index = rawArguments.index(after: index)
                guard
                    index < rawArguments.endIndex,
                    let value = Double(rawArguments[index]),
                    value >= 1
                else {
                    throw ArgumentError.invalidValue("--dominance")
                }
                dominanceRatio = value
            case "--sequences":
                index = rawArguments.index(after: index)
                guard
                    index < rawArguments.endIndex,
                    let value = Int(rawArguments[index]),
                    value > 0
                else {
                    throw ArgumentError.invalidValue("--sequences")
                }
                sequenceTarget = value
            case "--label":
                index = rawArguments.index(after: index)
                guard
                    index < rawArguments.endIndex,
                    !rawArguments[index].isEmpty
                else {
                    throw ArgumentError.missingValue("--label")
                }
                runLabel = String(rawArguments[index])
            case "--help", "-h":
                Self.printUsage()
                exit(EXIT_SUCCESS)
            default:
                throw ArgumentError.unknownArgument(String(argument))
            }

            index = rawArguments.index(after: index)
        }
    }

    private static func parseTrigger(_ value: String) throws -> TriggerType {
        switch value {
        case "caps-lock":
            return .capsLock
        case "right-option":
            return .rightOption
        default:
            throw ArgumentError.invalidValue("--trigger")
        }
    }

    static func printUsage() {
        print(
            """
            Usage: wheel-input-spike [options]

              --trigger caps-lock|right-option  Trigger to test (default: caps-lock)
              --distance POINTS                 Minimum horizontal travel (default: 80)
              --dominance RATIO                 Horizontal/vertical ratio (default: 1.5)
              --sequences COUNT                 Stop after observed sequences (default: 100)
              --label TEXT                      Privacy-safe label for this test run
              --help                            Show this help
            """
        )
    }
}

private enum ArgumentError: Error, CustomStringConvertible {
    case missingValue(String)
    case invalidValue(String)
    case unknownArgument(String)

    var description: String {
        switch self {
        case let .missingValue(argument):
            return "Missing value for \(argument)."
        case let .invalidValue(argument):
            return "Invalid value for \(argument)."
        case let .unknownArgument(argument):
            return "Unknown argument: \(argument)."
        }
    }
}

private func format(_ displacement: PointerDisplacement) -> String {
    String(
        format: "dx=%+.1f dy=%+.1f",
        displacement.horizontal,
        displacement.vertical
    )
}

private let processStartedAt = ProcessInfo.processInfo.systemUptime

private func log(_ message: String) {
    let elapsed = ProcessInfo.processInfo.systemUptime - processStartedAt
    print(String(format: "[%8.3f] %@", elapsed, message))
}

private let arguments: Arguments
do {
    arguments = try Arguments(CommandLine.arguments.dropFirst())
} catch {
    fputs("Error: \(error)\n\n", stderr)
    Arguments.printUsage()
    exit(EXIT_FAILURE)
}

print("Wheel M1 global-input spike")
print("Trigger: \(arguments.triggerType.rawValue)")
print(
    "Classifier: distance >= \(arguments.minimumDistance), "
        + "horizontal dominance >= \(arguments.dominanceRatio)x"
)
print("Run label: \(arguments.runLabel)")
print("Observed-sequence target: \(arguments.sequenceTarget)")
print("Mode: listen-only; Wheel will not block or rewrite input.\n")

if !InputMonitoringPermission.isGranted {
    print("Input Monitoring permission is not granted. Requesting it now…")

    guard InputMonitoringPermission.request() else {
        print(
            """

            Permission is still unavailable.
            Enable Xcode (or Terminal, when running there) in:
            System Settings > Privacy & Security > Input Monitoring

            Restart the host app, then run the spike again.
            """
        )
        exit(2)
    }
}

let classifier = HorizontalGestureClassifier(
    minimumHorizontalDistance: arguments.minimumDistance,
    minimumDominanceRatio: arguments.dominanceRatio
)
let monitor = GlobalInputMonitor(
    configuration: .init(
        triggerType: arguments.triggerType,
        classifier: classifier
    )
)
var statistics = InputSpikeRunStatistics()

private func formatMilliseconds(_ value: Double?) -> String {
    guard let value else {
        return "n/a"
    }

    return String(format: "%.2f ms", value)
}

private func printSummary(
    statistics: InputSpikeRunStatistics,
    arguments: Arguments
) {
    print(
        """

        --- SPIKE RUN SUMMARY ---
        label: \(arguments.runLabel)
        observed sequences: \(statistics.completedSequenceCount)/\(arguments.sequenceTarget)
        LEFT / RIGHT / NONE: \(statistics.leftCount) / \(statistics.rightCount) / \(statistics.noneCount)
        callback samples: \(statistics.callbackSampleCount)
        median callback latency: \(formatMilliseconds(statistics.medianCallbackLatencyMilliseconds))
        event-tap recoveries: \(statistics.eventTapRecoveryCount)

        This is measurement evidence, not an automatic GO decision. Compare it
        with the number of deliberate physical attempts and record conflicts,
        stuck states, device/app conditions, and side effects separately.
        """
    )
}

monitor.onEvent = { event in
    switch event {
    case let .callbackObserved(latencyMilliseconds):
        statistics.recordCallbackLatency(milliseconds: latencyMilliseconds)
    case let .modifierSignal(keyCode, sampledDown, alphaShiftEnabled):
        log(
            "signal keyCode=\(keyCode) "
                + "sampledDown=\(sampledDown) "
                + "alphaShift=\(alphaShiftEnabled)"
        )
    case let .triggerBegan(origin):
        log(String(format: "BEGIN x=%.1f y=%.1f", origin.x, origin.y))
    case let .pointerMoved(displacement):
        log("MOVE  \(format(displacement))")
    case let .triggerEnded(direction, displacement, duration):
        statistics.recordCompletedSequence(direction: direction)
        let endDescription = String(
            format: "END   %@ %@ duration=%.3fs",
            direction.rawValue.uppercased(),
            format(displacement),
            duration
        )
        log(
            endDescription
                + " sequence=\(statistics.completedSequenceCount)/\(arguments.sequenceTarget)"
                + " median-callback="
                + formatMilliseconds(statistics.medianCallbackLatencyMilliseconds)
        )
        print()

        if statistics.completedSequenceCount >= arguments.sequenceTarget {
            printSummary(statistics: statistics, arguments: arguments)
            exit(EXIT_SUCCESS)
        }
    case .eventTapRecovered:
        statistics.recordEventTapRecovery()
        log("WARN  event tap timed out and was re-enabled")
    }
}

do {
    try monitor.start()
    log("Ready. Hold the trigger, move left or right, then release. Press Control-C to stop.\n")
    RunLoop.main.run()
} catch {
    fputs("Unable to start monitor: \(error)\n", stderr)
    exit(3)
}
