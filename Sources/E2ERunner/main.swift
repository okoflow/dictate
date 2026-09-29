import Foundation

// `make e2e` entry point. Exit code: 0 green, 1 a check failed, 2 nothing failed but a check
// is blocked on a user action (permission, missing tool). Run from the repository root.

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let checks = AppChecks(
    buildDirectory: root.appendingPathComponent("build"),
    scratchDirectory: URL(fileURLWithPath: NSTemporaryDirectory())
)

@MainActor
func timed(_ name: String, _ body: () -> Outcome) -> CheckResult {
    let start = Date()
    let outcome = body()
    let result = CheckResult(name: name, outcome: outcome, seconds: Date().timeIntervalSince(start))
    print("[\(outcome.label)] \(name)\(outcome.detail.map { " — \($0)" } ?? "")")
    return result
}

let results: [CheckResult] = [
    timed("fixtures-valid") {
        FixtureChecks.run(
            manifestURL: root.appendingPathComponent("fixtures/manifest.json"),
            generatedDirectory: root.appendingPathComponent("fixtures/generated")
        )
    },
    timed("dictate-signature-stable") { checks.dictateSignatureIsStable() },
    timed("dictate-launches-as-menu-bar-app") { checks.dictateLaunchesAsMenuBarApp() },
    timed("dictate-reports-permissions") { checks.dictateReportsPermissions() },
    timed("dictate-permissions-granted") { checks.dictatePermissionsGranted() },
    timed("testpad-launches") { checks.testPadLaunches() },
    timed("testpad-accessibility-roundtrip") { checks.testPadAccessibilityRoundTrip() },
]
checks.cleanUp()

let report = Report(results: results, date: Date())
if let url = try? report.save(in: root.appendingPathComponent("e2e/reports")) {
    print("Report: \(url.path)")
}

exit(report.exitCode)
