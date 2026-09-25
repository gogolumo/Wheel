import Darwin
import Foundation
import WheelMacOS

private func printUsage() {
    print("Usage: wheel-evidence-check PATH")
}

guard CommandLine.arguments.count == 2 else {
    printUsage()
    exit(64)
}

do {
    let url = URL(fileURLWithPath: CommandLine.arguments[1])
    let data = try Data(contentsOf: url)
    let summary = try JSONDecoder().decode(InputSpikeRunSummary.self, from: data)
    let assessment = InputSpikeEvidenceAssessment.evaluate(summary)

    print("Automated evidence checks: \(assessment.outcome.rawValue.uppercased())")
    for finding in assessment.findings {
        print("- \(finding)")
    }
    print("Manual physical matrix review is still required; this is not a GO decision.")

    switch assessment.outcome {
    case .passed:
        exit(EXIT_SUCCESS)
    case .incomplete:
        exit(2)
    case .failed:
        exit(1)
    }
} catch {
    fputs("Unable to validate evidence: \(error)\n", stderr)
    exit(1)
}
