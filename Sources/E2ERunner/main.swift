import DictateCore
import Foundation

// `make e2e` entry point. Exit code: 0 green, 1 a check failed, 2 nothing failed but a check
// is blocked on a user action (permission, missing tool). Run from the repository root.

// Ctrl-C or `kill` must not leave Option held down or Dictate recording; see AbortGuard.
AbortGuard.healKeyboard()
let abortSources = AbortGuard.install()

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

let pushToTalk = PushToTalkChecks(
    dictate: checks.dictate,
    testPad: checks.testPad,
    log: EventLog(url: checks.eventLogURL, recordingDirectory: checks.recordingDirectory),
    fixture: root.appendingPathComponent("fixtures/generated/en-plain-2.wav"),
    testPadStateURL: checks.stateURL,
    fixturesDirectory: root.appendingPathComponent("fixtures"),
    transcriptDirectory: checks.transcriptDirectory
)

/// Everything `make e2e` (smoke) runs, in order; `make e2e-full` adds the rest around it.
enum Suite: String {
    case smoke
    case full
}

let suite = argumentValue(after: "--suite").flatMap(Suite.init(rawValue:)) ?? .smoke

/// Runs the steps in order and stops at the first that does not pass, so that is the reason reported.
/// The last measurement made on the way is kept.
func firstProblem(_ steps: [() -> Outcome]) -> Outcome {
    var measurement: String?
    for step in steps {
        switch step() {
        case .pass:
            continue
        case let .measured(note):
            measurement = note
        case let problem:
            return problem
        }
    }
    return measurement.map(Outcome.measured) ?? .pass
}

let appReady = { () -> Outcome in
    firstProblem([
        { checks.modelIsInstalled() },
        { checks.dictateSignatureIsStable() },
        { checks.dictateLaunchesAsMenuBarApp() },
        { checks.dictateReportsPermissions() },
        { checks.dictatePermissionsGranted() },
        { pushToTalk.blackHoleAvailable() },
        { pushToTalk.hotkeyReady() },
        { checks.modelIsReady(log: pushToTalk.log) },
    ])
}

/// TestPad is only needed for the Option+letter check; the smoke suite starts it here.
let optionLetter = { () -> Outcome in
    firstProblem([
        { checks.testPad.runningApplication == nil ? checks.testPadLaunches() : .pass },
        { pushToTalk.optionLetterPassesThrough() },
    ])
}

let plan: [(name: String, run: () -> Outcome)] = switch suite {
case .smoke:
    [
        ("app-ready", appReady),
        ("record-fixture-through-blackhole", { pushToTalk.recordFixtureThroughBlackHole() }),
        ("option-letter-passes-through", optionLetter),
        ("dictate-fixture-to-clipboard", { pushToTalk.dictateFixtureToClipboard() }),
    ]
case .full:
    [
        ("fixtures-valid", {
            FixtureChecks.run(
                manifestURL: root.appendingPathComponent("fixtures/manifest.json"),
                generatedDirectory: root.appendingPathComponent("fixtures/generated")
            )
        }),
        ("app-ready", appReady),
        ("testpad-launches", { checks.testPadLaunches() }),
        ("testpad-accessibility-roundtrip", { checks.testPadAccessibilityRoundTrip() }),
        // Order matters: the recording checks leave the app idle for the next one, and the Option+letter
        // check needs TestPad frontmost.
        ("record-fixture-through-blackhole", { pushToTalk.recordFixtureThroughBlackHole() }),
        ("silence-control", { pushToTalk.silenceControl() }),
        ("left-option-ignored", { pushToTalk.leftOptionIgnored() }),
        ("short-press-discarded", { pushToTalk.shortPressDiscarded() }),
        ("overlay-shown-and-hidden", { pushToTalk.overlayShownAndHidden() }),
        ("option-letter-passes-through", optionLetter),
        ("dictate-fixture-to-clipboard", { pushToTalk.dictateFixtureToClipboard() }),
    ]
}
print("E2E suite: \(suite.rawValue)")
let results = plan.map { name, run in timed(name, run) }
checks.cleanUp()

let report = Report(suite: suite.rawValue, results: results, date: Date())
if let url = try? report.save(in: root.appendingPathComponent("e2e/reports")) {
    print("Report: \(url.path)")
}

// The signal sources must live until here.
withExtendedLifetime(abortSources) { exit(report.exitCode) }
