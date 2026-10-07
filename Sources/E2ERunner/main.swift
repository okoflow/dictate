import DictateCore
import Foundation

// `make e2e` entry point. Exit code: 0 green, 1 a check failed, 2 nothing failed but a check
// is blocked on a user action (permission, missing tool). Run from the repository root.

// Ctrl-C or `kill` must not leave Option held down or Dictate recording; see AbortGuard.
AbortGuard.healKeyboard()
let abortSources = AbortGuard.install()

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let proxy: LLMProxy
do {
    proxy = try LLMProxy(cassetteURL: root.appendingPathComponent("e2e/cassettes/llm.json"))
} catch {
    print("cannot start the local LLM proxy: \(error)")
    exit(1)
}

let checks = AppChecks(
    buildDirectory: root.appendingPathComponent("build"),
    scratchDirectory: URL(fileURLWithPath: NSTemporaryDirectory()),
    llmEndpoint: proxy.endpoint
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

let live = ProcessInfo.processInfo.environment["E2E_LLM"] == "live"
let modes = ModeChecks(
    log: pushToTalk.log,
    proxy: proxy,
    fixturesDirectory: root.appendingPathComponent("fixtures"),
    transcriptDirectory: checks.transcriptDirectory,
    live: live,
    liveKey: live ? LiveKey.read() : nil
)

/// The M4 checks, the same in both suites.
let modeChecks: [(name: String, run: () -> Outcome)] = [
    ("mode-cycle-hotkey", { modes.modeCycleHotkey() }),
    ("modes-offline", { modes.offlineModes() }),
    ("cloud-plumbing", { modes.cloudPlumbing() }),
    ("cloud-fallback", { modes.cloudFallback() }),
    ("modes-cloud", { modes.cloudModes() }),
    ("clean-latency", { modes.cleanLatency() }),
]

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

let clipboardOnly = { () -> Outcome in
    firstProblem([
        { checks.dictateLaunchesAsMenuBarApp(extraArguments: ["--clipboard-only"]) },
        { pushToTalk.hotkeyReady() },
        { checks.modelIsReady(log: pushToTalk.log) },
        { pushToTalk.dictateFixtureToClipboard() },
    ])
}

/// Runs last: whatever the suite pressed, no modifier may be left down in the system.
let modifiersReleased = { () -> Outcome in
    KeyboardDriver().releaseAll()
    Thread.sleep(forTimeInterval: 0.3)
    let stuck = KeyboardDriver.stuckModifiers()
    return stuck == 0 ? .pass : .fail("modifier bits still set after releasing everything: 0x" + String(stuck, radix: 16))
}

let plan: [(name: String, run: () -> Outcome)] = switch suite {
case .smoke:
    [
        ("app-ready", appReady),
        ("record-fixture-through-blackhole", { pushToTalk.recordFixtureThroughBlackHole() }),
        ("option-letter-passes-through", optionLetter),
        ("dictate-into-testpad", { pushToTalk.dictateIntoTestPad() }),
    ] + modeChecks
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
        ("dictate-into-testpad", { pushToTalk.dictateIntoTestPad() }),
        // The clipboard path (insertion off) needs its own launch of the app.
        ("dictate-fixture-to-clipboard", clipboardOnly),
    ] + modeChecks
}
/// `--only a,b`: run just these checks of the suite (for working on them; a stage hand-off runs everything).
let only = argumentValue(after: "--only").map { Set($0.split(separator: ",").map(String.init)) }
let selected = only.map { names in plan.filter { names.contains($0.name) } } ?? plan
print("E2E suite: \(suite.rawValue)" + (only == nil ? "" : " (only \(selected.map(\.name).joined(separator: ", ")))"))
let results = (selected + [("modifiers-released", modifiersReleased)]).map { name, run in timed(name, run) }
checks.cleanUp()
proxy.stop()

let report = Report(suite: suite.rawValue + (only == nil ? "" : " (partial: --only)"), results: results, date: Date())
if let url = try? report.save(in: root.appendingPathComponent("e2e/reports")) {
    print("Report: \(url.path)")
}

// The signal sources must live until here.
withExtendedLifetime(abortSources) { exit(report.exitCode) }
