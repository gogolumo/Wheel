import Darwin
import Foundation
import WheelMacOS

private func printUsage() {
    print("Usage: wheel-evidence-check PATH [PATH ...]")
}

guard CommandLine.arguments.count >= 2 else {
    printUsage()
    exit(64)
}

var assessments: [InputSpikeEvidenceAssessment] = []
var unreadableFileCount = 0

for path in CommandLine.arguments.dropFirst() {
    print("\nEvidence file: \(path)")
    do {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let summary = try JSONDecoder().decode(InputSpikeRunSummary.self, from: data)
        let assessment = InputSpikeEvidenceAssessment.evaluate(summary)
        assessments.append(assessment)
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

let batch = InputSpikeEvidenceBatchAssessment.evaluate(assessments)
print(
    "\nBatch result: \(batch.outcome.rawValue.uppercased()) "
        + "(\(batch.passedCount) passed, \(batch.incompleteCount) incomplete, "
        + "\(batch.failedCount + unreadableFileCount) failed)"
)
print("Manual physical matrix review is still required; this is not a GO decision.")

if unreadableFileCount > 0 || batch.outcome == .failed {
    exit(1)
}
if batch.outcome == .incomplete {
    exit(2)
}
exit(EXIT_SUCCESS)
