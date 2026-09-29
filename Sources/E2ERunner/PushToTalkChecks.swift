import ApplicationServices
import AudioDevices
import DictateCore
import Foundation

/// The M1 checks: hold right Option, and Dictate records, shows its overlay, and stays out of the way.
///
/// They drive the real app with synthetic key events and "speak" a fixture into it through BlackHole.
/// Every check compares against a snapshot taken just before its own action, so results never depend
/// on what an earlier check left in the event log or the recording directory.
@MainActor
struct PushToTalkChecks {
    static let maximumLatency = 0.6

    let dictate: AppLauncher
    let testPad: AppLauncher
    let log: EventLog
    let fixture: URL
    let testPadStateURL: URL

    var keyboard: KeyboardDriver {
        KeyboardDriver()
    }

    var session: RecordingSession {
        RecordingSession(dictate: dictate, log: log, keyboard: keyboard)
    }

    /// Turns a `Verdict` thrown anywhere in a check into the matching `Outcome`.
    func run(_ body: () throws -> Outcome) -> Outcome {
        do {
            return try body()
        } catch let Verdict.fail(message) {
            return .fail(message)
        } catch let Verdict.blocked(message) {
            return .blocked(message)
        } catch {
            return .fail("\(error)")
        }
    }

    // MARK: Checks

    func hotkeyReady() -> Outcome {
        run {
            try session.requireHotkey()
            return .pass
        }
    }

    /// Fails if BlackHole is missing, but as BLOCKED: it is a tool to install, not a defect.
    func blackHoleAvailable() -> Outcome {
        run {
            guard AudioDevices.find(AudioDevices.blackHoleUID, direction: .input) != nil
                || AudioDevices.find("BlackHole 2ch", direction: .input) != nil
            else {
                throw Verdict.blocked("BlackHole 2ch is not installed: brew install blackhole-2ch")
            }
            return .pass
        }
    }

    func recordFixtureThroughBlackHole() -> Outcome {
        run {
            let environment = try session.environment()
            let playback = try prepareFixturePlayback(on: environment.blackHole)
            let capture = try session.capture(playing: playback, silence: 0)
            try verify(capture, device: environment.blackHole)
            let heard = AudioLevel.speechSpan(of: capture.samples, sampleRate: 16000) ?? 0
            let expected = try AudioLevel.speechSpan(of: WAVReader.samples(at: fixture), sampleRate: 16000) ?? 0
            // Released right at the end of playback: a missing tail would show as speech that is too short.
            guard abs(heard - expected) <= 0.25, expected - heard <= 0.1 else {
                throw Verdict.fail(String(format: "speech lasts %.2f s in the recording, %.2f s in the fixture", heard, expected))
            }
            return .measured(String(
                format: "press to first audio %.0f ms; held %.2f s, kept %.2f s; speech %.2f s vs fixture %.2f s",
                capture.latency * 1000, capture.seconds, Double(capture.samples.count) / 16000, heard, expected
            ))
        }
    }

    /// Same hold with nothing played: proves the previous check measured the fixture, not noise.
    func silenceControl() -> Outcome {
        run {
            _ = try session.environment()
            let capture = try session.capture(playing: nil, silence: 1.5)
            // Non-finite or full-scale samples are not "someone else's audio": the app produced garbage.
            guard capture.samples.allSatisfy({ $0.isFinite && abs($0) < 0.99 }) else {
                throw Verdict.fail("the silent recording contains non-finite or full-scale samples")
            }
            let level = AudioLevel.rms(capture.samples)
            guard level < 0.001 else {
                throw Verdict.blocked(String(format: "something else routes audio into BlackHole (rms %.4f)", level))
            }
            return .pass
        }
    }

    func leftOptionIgnored() -> Outcome {
        run {
            _ = try session.environment()
            let baseline = log.baseline()
            keyboard.holding(.leftOption) { Thread.sleep(forTimeInterval: 1) }
            Thread.sleep(forTimeInterval: 0.3)
            let events = log.newEvents(since: baseline)
            guard events.isEmpty, log.newFiles(since: baseline).isEmpty else {
                throw Verdict.fail("left Option triggered the app: \(events)")
            }
            return .pass
        }
    }

    func shortPressDiscarded() -> Outcome {
        run {
            let environment = try session.environment()
            let baseline = log.baseline()
            keyboard.holding(.rightOption) { Thread.sleep(forTimeInterval: 0.1) }
            let discarded = try session.waitFor(since: baseline, timeout: 2) { $0 == .recordingDiscarded(.tooShort) }
            guard discarded else { throw Verdict.fail("no recordingDiscarded(tooShort): \(log.newEvents(since: baseline))") }
            Thread.sleep(forTimeInterval: 0.5)
            guard log.newFiles(since: baseline).isEmpty else { throw Verdict.fail("a 0.1 s press left a recording behind") }
            let overlayShown = OverlayProbe.onScreen(pid: environment.dictatePID)
            guard !overlayShown, !log.newEvents(since: baseline).contains(.overlayShown) else {
                throw Verdict.fail("a 0.1 s press showed the overlay")
            }
            return .pass
        }
    }

    func overlayShownAndHidden() -> Outcome {
        run {
            let environment = try session.environment()
            let pid = environment.dictatePID
            // The overlay must not take focus, which only means something with TestPad in front.
            _ = try prepareTestPad()
            let baseline = log.baseline()
            try keyboard.holding(.rightOption) {
                Thread.sleep(forTimeInterval: 0.8)
                let visible = waitUntil(timeout: 1.5) {
                    OverlayProbe.inAccessibilityTree(pid: pid) && OverlayProbe.onScreen(pid: pid)
                }
                guard visible else {
                    throw Verdict.fail(
                        "overlay not visible after 0.8 s: accessibility \(OverlayProbe.inAccessibilityTree(pid: pid)), "
                            + "on screen \(OverlayProbe.onScreen(pid: pid))"
                    )
                }
                guard testPadIsFrontmost() else { throw Verdict.fail("the overlay took focus from TestPad") }
            }
            let gone = waitUntil(timeout: 1) { !OverlayProbe.inAccessibilityTree(pid: pid) && !OverlayProbe.onScreen(pid: pid) }
            guard gone else { throw Verdict.fail("overlay still there 1 s after the release") }
            let finished = try session.waitFor(since: baseline, timeout: 5) { event in
                if case .recordingFinished = event {
                    true
                } else {
                    false
                }
            }
            let events = log.newEvents(since: baseline)
            guard finished, events.contains(.overlayShown), events.contains(.overlayHidden) else {
                throw Verdict.fail("event log lacks overlayShown/overlayHidden/recordingFinished: \(events)")
            }
            return .pass
        }
    }

    // MARK: Helpers

    private func prepareFixturePlayback(on device: AudioDevice) throws -> PreparedPlayback {
        do {
            return try PreparedPlayback(wavAt: fixture, on: device)
        } catch {
            throw Verdict.fail("cannot prepare playback into \(device.name): \(error)")
        }
    }

    /// Checks the recording against what the app said and what was played.
    private func verify(_ capture: Capture, device: AudioDevice) throws {
        guard capture.device == device.name else {
            throw Verdict.fail("recorded from \"\(capture.device)\", expected \"\(device.name)\"")
        }
        guard capture.latency <= Self.maximumLatency else {
            throw Verdict.fail(String(
                format: "first audio came %.0f ms after the key press (limit %.0f ms)",
                capture.latency * 1000, Self.maximumLatency * 1000
            ))
        }
        // Audio starts with the first buffer, so the part of the hold before it cannot be in the file.
        let kept = Double(capture.samples.count) / 16000
        let expected = capture.seconds - capture.latency
        // The upper bound catches a recording that runs on past the release; the tail wait is 150 ms at most.
        guard abs(kept - expected) <= 0.3, kept <= capture.seconds + 0.15 else {
            throw Verdict.fail(String(format: "kept %.2f s of audio, expected %.2f s (%.2f s hold, %.2f s start-up)",
                                      kept, expected, capture.seconds, capture.latency))
        }
    }
}
