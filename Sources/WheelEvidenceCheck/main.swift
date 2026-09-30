import Darwin
import Foundation
import WheelDomain
import WheelMacOS

private func printUsage() {
    print(
        "Usage: wheel-evidence-check "
            + "[--require-trigger capsLock|rightOption|mouseSideButton]... "
            + "[--expected-trigger caps-lock|right-option|mouse-side-button] "
            + "[--minimum-observed COUNT] "
            + "[--maximum-median-latency-ms MILLISECONDS] "
            + "PATH [PATH ...]"
    )
}

private func parseExpectedTrigger(_ value: String) -> TriggerType? {
    switch value {
    case "caps-lock", "capsLock":
        return .capsLock
    case "right-option", "rightOption":
        return .rightOption
    case "mouse-side-button", "mouseSideButton":
        return .mouseSideButton
    default:
        return nil
    }
}

guard CommandLine.arguments.count >= 2 else {
    printUsage()
    exit(64)
}

var entries: [InputSpikeEvidenceBatchEntry] = []
var unreadableFileCount = 0
var requiredTriggers: Set<String> = []
var evidencePaths: [String] = []
let supportedTriggers = Set(["capsLock", "rightOption", "mouseSideButton"])
var expectedTrigger: TriggerType?
var minimumObservedSequenceCount: Int?
var maximumMedianCallbackLatencyMilliseconds: Double?

var argumentIndex = 1
while argumentIndex < CommandLine.arguments.count {
    let argument = CommandLine.arguments[argumentIndex]
    if argument == "--require-trigger" {
        argumentIndex += 1
        guard argumentIndex < CommandLine.arguments.count else {
            printUsage()
            exit(64)
        }
        let trigger = CommandLine.arguments[argumentIndex]
        guard supportedTriggers.contains(trigger) else {
            print("Unsupported required trigger: \(trigger)")
            printUsage()
            exit(64)
        }
        requiredTriggers.insert(trigger)
    } else if argument == "--expected-trigger" {
        argumentIndex += 1
        guard
            expectedTrigger == nil,
            argumentIndex < CommandLine.arguments.count,
            let parsed = parseExpectedTrigger(CommandLine.arguments[argumentIndex])
        else {
            print("Invalid or repeated --expected-trigger value")
            printUsage()
            exit(64)
        }
        expectedTrigger = parsed
    } else if argument == "--minimum-observed" {
        argumentIndex += 1
        guard
            minimumObservedSequenceCount == nil,
            argumentIndex < CommandLine.arguments.count,
            let parsed = Int(CommandLine.arguments[argumentIndex]),
            parsed > 0
        else {
            print("Invalid or repeated --minimum-observed value")
            printUsage()
            exit(64)
        }
        minimumObservedSequenceCount = parsed
    } else if argument == "--maximum-median-latency-ms" {
        argumentIndex += 1
        guard
            maximumMedianCallbackLatencyMilliseconds == nil,
            argumentIndex < CommandLine.arguments.count,
            let parsed = Double(CommandLine.arguments[argumentIndex]),
            parsed.isFinite,
            parsed > 0
        else {
            print("Invalid or repeated --maximum-median-latency-ms value")
            printUsage()
            exit(64)
        }
        maximumMedianCallbackLatencyMilliseconds = parsed
    } else if argument.hasPrefix("-") {
        print("Unknown option: \(argument)")
        printUsage()
        exit(64)
    } else {
        evidencePaths.append(argument)
    }
    argumentIndex += 1
}

guard !evidencePaths.isEmpty else {
    printUsage()
    exit(64)
}

let requirements = InputSpikeEvidenceRequirements(
    expectedTrigger: expectedTrigger,
    minimumObservedSequenceCount: minimumObservedSequenceCount,
    maximumMedianCallbackLatencyMilliseconds: maximumMedianCallbackLatencyMilliseconds
)

for path in evidencePaths {
    print("\nEvidence file: \(path)")
    do {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let summary = try JSONDecoder().decode(InputSpikeRunSummary.self, from: data)
        let assessment = InputSpikeEvidenceAssessment.evaluate(
            summary,
            requirements: requirements
        )
        entries.append(
            InputSpikeEvidenceBatchEntry(
                runLabel: summary.runLabel,
                trigger: summary.trigger,
                assessment: assessment
            )
        )
        print("Automated checks: \(assessment.outcome.rawValue.uppercased())")
        for finding in assessment.findings {
            print("- \(finding)")
        }
    } catch {
        unreadableFileCount += 1
        print("Automated checks: FAILED")
        print("- unable to read or decode evidence: \(error)")
    }
}

let batch = InputSpikeEvidenceBatchAssessment.evaluate(
    entries,
    requiredTriggers: requiredTriggers
)
print(
    "\nBatch result: \(batch.outcome.rawValue.uppercased()) "
        + "(\(batch.passedCount) passed, \(batch.incompleteCount) incomplete, "
        + "\(batch.failedCount + unreadableFileCount) failed)"
)
if !batch.duplicateRunLabels.isEmpty {
    let labels = batch.duplicateRunLabels.joined(separator: ", ")
    print("- duplicate runLabel values: \(labels)")
}
if !batch.missingRequiredTriggers.isEmpty {
    let triggers = batch.missingRequiredTriggers.joined(separator: ", ")
    print("- missing required trigger evidence: \(triggers)")
}
print("Manual physical matrix review is still required; this is not a GO decision.")

if unreadableFileCount > 0 || batch.outcome == .failed {
    exit(1)
}
if batch.outcome == .incomplete {
    exit(2)
}
exit(EXIT_SUCCESS)
