import Darwin
import Foundation
import WheelDomain
import WheelMacOS

private func printUsage() {
    print(
        "Usage: wheel-evidence-check "
            + "[--require-trigger capsLock|rightOption|mouseSideButton]... "
            + "[--minimum-runs-per-trigger TRIGGER COUNT]... "
            + "[--require-run LABEL TRIGGER]... "
            + "[--attempt-count LABEL COUNT]... "
            + "[--required-attempt-count COUNT] "
            + "[--maximum-missed-attempts COUNT] "
            + "[--expected-trigger caps-lock|right-option|mouse-side-button] "
            + "[--expected-sequence-target COUNT] "
            + "[--minimum-observed COUNT] "
            + "[--minimum-left COUNT] "
            + "[--minimum-right COUNT] "
            + "[--minimum-none COUNT] "
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
var minimumRunCountByTrigger: [String: Int] = [:]
var requiredRuns: [String: String] = [:]
var attestedAttemptCountByRunLabel: [String: Int] = [:]
var requiredAttemptCount: Int?
var maximumMissedAttemptCount: Int?
var evidencePaths: [String] = []
let supportedTriggers = Set(["capsLock", "rightOption", "mouseSideButton"])
var expectedTrigger: TriggerType?
var expectedSequenceTarget: Int?
var minimumObservedSequenceCount: Int?
var minimumLeftSequenceCount: Int?
var minimumRightSequenceCount: Int?
var minimumNoneSequenceCount: Int?
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
    } else if argument == "--minimum-runs-per-trigger" {
        argumentIndex += 1
        guard argumentIndex < CommandLine.arguments.count else {
            printUsage()
            exit(64)
        }
        let trigger = CommandLine.arguments[argumentIndex]
        argumentIndex += 1
        guard
            supportedTriggers.contains(trigger),
            minimumRunCountByTrigger[trigger] == nil,
            argumentIndex < CommandLine.arguments.count,
            let count = Int(CommandLine.arguments[argumentIndex]),
            count > 0
        else {
            print("Invalid or repeated --minimum-runs-per-trigger value")
            printUsage()
            exit(64)
        }
        minimumRunCountByTrigger[trigger] = count
    } else if argument == "--require-run" {
        argumentIndex += 1
        guard argumentIndex < CommandLine.arguments.count else {
            printUsage()
            exit(64)
        }
        let runLabel = CommandLine.arguments[argumentIndex]
        argumentIndex += 1
        guard
            InputEvidenceRunLabel.validationError(for: runLabel) == nil,
            requiredRuns[runLabel] == nil,
            argumentIndex < CommandLine.arguments.count,
            supportedTriggers.contains(CommandLine.arguments[argumentIndex])
        else {
            print("Invalid or repeated --require-run value")
            printUsage()
            exit(64)
        }
        requiredRuns[runLabel] = CommandLine.arguments[argumentIndex]
    } else if argument == "--attempt-count" {
        argumentIndex += 1
        guard argumentIndex < CommandLine.arguments.count else {
            printUsage()
            exit(64)
        }
        let runLabel = CommandLine.arguments[argumentIndex]
        argumentIndex += 1
        guard
            InputEvidenceRunLabel.validationError(for: runLabel) == nil,
            attestedAttemptCountByRunLabel[runLabel] == nil,
            argumentIndex < CommandLine.arguments.count,
            let count = Int(CommandLine.arguments[argumentIndex]),
            count > 0
        else {
            print("Invalid or repeated --attempt-count value")
            printUsage()
            exit(64)
        }
        attestedAttemptCountByRunLabel[runLabel] = count
    } else if argument == "--required-attempt-count" {
        argumentIndex += 1
        guard
            requiredAttemptCount == nil,
            argumentIndex < CommandLine.arguments.count,
            let count = Int(CommandLine.arguments[argumentIndex]),
            count > 0
        else {
            print("Invalid or repeated --required-attempt-count value")
            printUsage()
            exit(64)
        }
        requiredAttemptCount = count
    } else if argument == "--maximum-missed-attempts" {
        argumentIndex += 1
        guard
            maximumMissedAttemptCount == nil,
            argumentIndex < CommandLine.arguments.count,
            let count = Int(CommandLine.arguments[argumentIndex]),
            count >= 0
        else {
            print("Invalid or repeated --maximum-missed-attempts value")
            printUsage()
            exit(64)
        }
        maximumMissedAttemptCount = count
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
    } else if argument == "--expected-sequence-target" {
        argumentIndex += 1
        guard
            expectedSequenceTarget == nil,
            argumentIndex < CommandLine.arguments.count,
            let parsed = Int(CommandLine.arguments[argumentIndex]),
            parsed > 0
        else {
            print("Invalid or repeated --expected-sequence-target value")
            printUsage()
            exit(64)
        }
        expectedSequenceTarget = parsed
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
    } else if argument == "--minimum-left" {
        argumentIndex += 1
        guard
            minimumLeftSequenceCount == nil,
            argumentIndex < CommandLine.arguments.count,
            let parsed = Int(CommandLine.arguments[argumentIndex]),
            parsed > 0
        else {
            print("Invalid or repeated --minimum-left value")
            printUsage()
            exit(64)
        }
        minimumLeftSequenceCount = parsed
    } else if argument == "--minimum-right" {
        argumentIndex += 1
        guard
            minimumRightSequenceCount == nil,
            argumentIndex < CommandLine.arguments.count,
            let parsed = Int(CommandLine.arguments[argumentIndex]),
            parsed > 0
        else {
            print("Invalid or repeated --minimum-right value")
            printUsage()
            exit(64)
        }
        minimumRightSequenceCount = parsed
    } else if argument == "--minimum-none" {
        argumentIndex += 1
        guard
            minimumNoneSequenceCount == nil,
            argumentIndex < CommandLine.arguments.count,
            let parsed = Int(CommandLine.arguments[argumentIndex]),
            parsed > 0
        else {
            print("Invalid or repeated --minimum-none value")
            printUsage()
            exit(64)
        }
        minimumNoneSequenceCount = parsed
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
    expectedSequenceTarget: expectedSequenceTarget,
    minimumObservedSequenceCount: minimumObservedSequenceCount,
    minimumLeftSequenceCount: minimumLeftSequenceCount,
    minimumRightSequenceCount: minimumRightSequenceCount,
    minimumNoneSequenceCount: minimumNoneSequenceCount,
    maximumMedianCallbackLatencyMilliseconds: maximumMedianCallbackLatencyMilliseconds
)

for (index, path) in evidencePaths.enumerated() {
    let evidenceNumber = index + 1
    print("\nEvidence file #\(evidenceNumber)")
    do {
        let url = URL(fileURLWithPath: path)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            unreadableFileCount += 1
            print("Automated checks: FAILED")
            print("- unable to read evidence file #\(evidenceNumber)")
            continue
        }

        let summary: InputSpikeRunSummary
        do {
            summary = try InputSpikeRunSummary.decodeValidatedJSON(data)
        } catch {
            unreadableFileCount += 1
            print("Automated checks: FAILED")
            print("- unable to decode evidence file #\(evidenceNumber)")
            continue
        }
        let assessment = InputSpikeEvidenceAssessment.evaluate(
            summary,
            requirements: requirements
        )
        entries.append(
            InputSpikeEvidenceBatchEntry(
                runLabel: summary.runLabel,
                trigger: summary.trigger,
                sequenceTarget: summary.sequenceTarget,
                completedSequenceCount: summary.completedSequenceCount,
                assessment: assessment
            )
        )
        print("Automated checks: \(assessment.outcome.rawValue.uppercased())")
        for finding in assessment.findings {
            print("- \(finding)")
        }
    }
}

let batch = InputSpikeEvidenceBatchAssessment.evaluate(
    entries,
    requiredTriggers: requiredTriggers,
    minimumRunCountByTrigger: minimumRunCountByTrigger,
    requiredRuns: requiredRuns,
    attestedAttemptCountByRunLabel: attestedAttemptCountByRunLabel,
    requiredAttemptCount: requiredAttemptCount,
    maximumMissedAttemptCount: maximumMissedAttemptCount
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
if !batch.insufficientTriggerRunCounts.isEmpty {
    let counts = batch.insufficientTriggerRunCounts.joined(separator: ", ")
    print("- insufficient independent trigger runs: \(counts)")
}
if !batch.requiredRunFindings.isEmpty {
    let findings = batch.requiredRunFindings.joined(separator: ", ")
    print("- required evidence runs: \(findings)")
}
if !batch.attemptCountFindings.isEmpty {
    let findings = batch.attemptCountFindings.joined(separator: ", ")
    print("- physical attempt attestations: \(findings)")
}
print("Manual physical matrix review is still required; this is not a GO decision.")

if unreadableFileCount > 0 || batch.outcome == .failed {
    exit(1)
}
if batch.outcome == .incomplete {
    exit(2)
}
exit(EXIT_SUCCESS)
