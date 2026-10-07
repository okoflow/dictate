import ApplicationServices
import DictateCore
import Foundation

/// The M4 checks: the text goes through the chosen mode, cloud modes talk only to the suite's LLM proxy, and
/// fall back to Light when it is slow or gone.
///
/// The fixtures are dictated through the app's test-only "dictate this WAV file" notification (the WAV audio
/// source), so these checks need neither key presses nor focus; the push-to-talk path itself is covered by the
/// M1–M3 checks. Dictate runs with `--insert-only-into TestPad`, so with TestPad in the background the text is
/// not pasted anywhere (`insertionSkipped(notAllowed)`) and is read from the transcript files instead.
@MainActor
struct ModeChecks {
    /// Clean must stay close to the manifest's `clean` text. The LLM may reorder words ("Созвон нужно
    /// перенести…"), which costs a lot of characters for the same meaning, hence the loose bound.
    static let maximumCleanErrorRate = 0.5
    /// Light only removes hesitations, so it stays as close to the spoken text as Raw (the M2 bound).
    static let maximumLightErrorRate = 0.15
    /// Plan target: from the end of a 10 s phrase to the text, Clean ≤ 2.5 s.
    static let maximumCleanLatency = 2.5
    static let fillerFixtures = ["ru-filler-1", "en-filler-1", "ko-filler-1"]
    /// The app the per-app mode check uses; the suite launches Dictate with Light for it.
    static let chrome = "com.google.Chrome"

    let log: EventLog
    let proxy: LLMProxy
    let fixturesDirectory: URL
    let transcriptDirectory: URL
    /// The app's `--dictionary` and `--history-file`.
    let dictionaryURL: URL
    let historyURL: URL
    /// `E2E_LLM=live`: the proxy forwards to the real API and records; otherwise it replays.
    let live: Bool
    let liveKey: String?

    /// What became of one dictated file.
    struct Delivery {
        let fixture: Fixture
        let raw: String
        let text: String
        let language: Language
        let mode: Mode
        let applied: Mode
        let fallback: FallbackReason?
        let cloud: Bool
        let processingSeconds: Double
        /// From posting the notification to the `processed` event, which comes right before the paste.
        let seconds: Double
    }

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

    // MARK: Offline modes

    /// Raw and Light on the filler fixtures of every language: Raw is Whisper's text, Light is exactly
    /// `LightRules` applied to it (no hesitations left, still close to what was said), and nothing reached the
    /// LLM proxy or was reported as a cloud request.
    func offlineModes() -> Outcome {
        run {
            proxy.behaviour = .stub
            let requestsBefore = proxy.received.count
            var notes: [String] = []
            for id in Self.fillerFixtures {
                let raw = try dictate(id, mode: .raw)
                guard raw.text == raw.raw, raw.applied == .raw, !raw.cloud else {
                    throw Verdict.fail("\(id) Raw: delivered \"\(raw.text)\" for \"\(raw.raw)\" (applied \(raw.applied))")
                }
                let light = try dictate(id, mode: .light)
                try requireLight(light)
                let rate = TextMetrics.cer(
                    reference: light.fixture.text, hypothesis: light.text, language: light.fixture.language
                )
                guard rate <= Self.maximumLightErrorRate else {
                    throw Verdict.fail(String(format: "\(id) Light is off by %.0f %%: \"\(light.text)\"", rate * 100))
                }
                notes.append(String(format: "\(light.fixture.language.rawValue) %.0f %%", rate * 100))
            }
            guard proxy.received.count == requestsBefore else {
                throw Verdict.fail("Raw/Light sent \(proxy.received.count - requestsBefore) request(s) to the LLM")
            }
            return .measured("no network requests; Light error " + notes.joined(separator: ", "))
        }
    }

    /// Light ran (no fallback reason expected unless given), and its text is `LightRules` applied to the raw text.
    func requireLight(_ delivery: Delivery, fallback: FallbackReason? = nil) throws {
        let expected = LightRules.apply(delivery.raw, language: delivery.language)
        guard delivery.applied == .light, delivery.fallback == fallback else {
            let reason = String(describing: delivery.fallback)
            throw Verdict.fail("\(delivery.fixture.id): applied \(delivery.applied), fallback \(reason)")
        }
        guard delivery.text == expected else {
            throw Verdict.fail("\(delivery.fixture.id): Light gave \"\(delivery.text)\", LightRules gives \"\(expected)\"")
        }
        if let hesitation = Self.words(of: delivery.text).first(where: LightRules.isHesitation) {
            throw Verdict.fail("\(delivery.fixture.id): \"\(hesitation)\" is left in \"\(delivery.text)\"")
        }
    }

    // MARK: Hotkey

    /// ⌃⌥M five times: every mode in turn, then back to the start (the launch's Raw, which is not saved).
    func modeCycleHotkey() -> Outcome {
        run {
            guard AXIsProcessTrusted() else {
                throw Verdict.blocked("Accessibility not granted to your terminal app (needed to post key events)")
            }
            let start = currentMode()
            let baseline = log.baseline()
            var expected: [Mode] = []
            var mode = start
            for _ in Mode.allCases {
                mode = mode.next
                expected.append(mode)
                KeyboardDriver().typeControlOption(key: KeyboardDriver.letterM)
                let seen = waitUntil(timeout: 2) { modeChanges(since: baseline).count == expected.count }
                guard seen else {
                    let changes = modeChanges(since: baseline)
                    throw Verdict.fail("⌃⌥M did not switch the mode (expected \(mode)); changes so far: \(changes)")
                }
            }
            guard modeChanges(since: baseline) == expected, mode == start else {
                throw Verdict.fail("modes went \(modeChanges(since: baseline)), expected \(expected)")
            }
            return .measured(expected.map(\.rawValue).joined(separator: " → "))
        }
    }

    // MARK: Dictating a file

    /// Sets `mode`, dictates the fixture `id` and waits for the result, which must be processed in `expected`
    /// (by default `mode`; an app with its own mode changes it).
    func dictate(_ id: String, mode: Mode, processedIn expected: Mode? = nil) throws -> Delivery {
        let fixture = try Self.fixture(id, in: fixturesDirectory)
        guard waitUntil(timeout: 180, { log.events.contains {
            if case .modelReady = $0 {
                true
            } else {
                false
            }
        } }) else {
            throw Verdict.fail("the app did not load the model within 180 s")
        }
        try setMode(mode)
        let wav = try Self.copyOutsideDocuments(fixturesDirectory.appendingPathComponent("generated/\(id).wav"))
        let baseline = log.baseline()
        let posted = Date()
        Self.post(TestNotification.dictateFile, object: wav.path)
        var progress = DictationProgress()
        let done = waitUntil(timeout: 60, interval: 0.01) { progress.read(log.newEvents(since: baseline)) }
        let seconds = Date().timeIntervalSince(posted)
        if let problem = progress.problem {
            throw Verdict.fail("\(id): \(problem)")
        }
        guard done, case let .processed(requested, applied, fallback, cloud, _, processingSeconds)? = progress.processed,
              let language = progress.language
        else {
            throw Verdict.fail("\(id): no delivery within 60 s (app logged: \(log.newEvents(since: baseline)))")
        }
        guard requested == expected ?? mode else {
            throw Verdict.fail("\(id): processed in \(requested), expected \(expected ?? mode)")
        }
        let (raw, text) = try latestTranscripts()
        return Delivery(
            fixture: fixture, raw: raw, text: text, language: language, mode: requested, applied: applied,
            fallback: fallback, cloud: cloud, processingSeconds: processingSeconds, seconds: seconds
        )
    }

    private func setMode(_ mode: Mode) throws {
        guard currentMode() != mode else { return }
        let baseline = log.baseline()
        Self.post(TestNotification.setMode, object: mode.rawValue)
        guard waitUntil(timeout: 3, { modeChanges(since: baseline).last == mode }) else {
            throw Verdict.fail("the app did not switch to \(mode)")
        }
    }

    /// The last mode the app reported, or the launch's `--mode raw`.
    private func currentMode() -> Mode {
        log.events.reversed().lazy.compactMap { event -> Mode? in
            if case let .modeChanged(mode) = event {
                mode
            } else {
                nil
            }
        }.first ?? .raw
    }

    private func modeChanges(since baseline: EventLog.Baseline) -> [Mode] {
        log.newEvents(since: baseline).compactMap { event in
            if case let .modeChanged(mode) = event {
                mode
            } else {
                nil
            }
        }
    }

    /// The newest `<n>.raw.txt` (recognised) and `<n>.txt` (delivered).
    private func latestTranscripts() throws -> (raw: String, text: String) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: transcriptDirectory.path)) ?? []
        guard let newest = names.compactMap({ $0.hasSuffix(".txt") ? Int($0.dropLast(4)) : nil }).max(),
              let raw = try? String(contentsOf: transcriptDirectory.appendingPathComponent("\(newest).raw.txt"), encoding: .utf8),
              let text = try? String(contentsOf: transcriptDirectory.appendingPathComponent("\(newest).txt"), encoding: .utf8)
        else { throw Verdict.fail("no transcript files in \(transcriptDirectory.path)") }
        return (raw, text)
    }

    /// A copy of `file` in the temporary directory. The repository may live in ~/Documents, which macOS guards
    /// with a permission prompt for every app; the app reads the copy instead, as it already writes its logs there.
    static func copyOutsideDocuments(_ file: URL) throws -> URL {
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("dictate-e2e-" + file.lastPathComponent)
        try? FileManager.default.removeItem(at: copy)
        do {
            try FileManager.default.copyItem(at: file, to: copy)
        } catch {
            throw Verdict.fail("cannot copy \(file.lastPathComponent) to the temporary directory: \(error)")
        }
        return copy
    }

    /// Posts a test notification to Dictate. The post goes out through the run loop, which this command-line
    /// tool otherwise never runs, so it is turned briefly.
    static func post(_ name: String, object: String) {
        DistributedNotificationCenter.default().postNotificationName(
            .init(name), object: object, userInfo: nil, deliverImmediately: true
        )
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }

    static func fixture(_ id: String, in fixturesDirectory: URL) throws -> Fixture {
        let manifest = try Fixture.load(from: fixturesDirectory.appendingPathComponent("manifest.json"))
        guard let fixture = manifest.first(where: { $0.id == id }) else { throw Verdict.fail("\(id) is not in the manifest") }
        return fixture
    }

    /// Lowercased words, punctuation dropped.
    static func words(of text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber && $0 != "-" }.map(String.init)
    }
}

/// What the app has said so far about one dictated file.
private struct DictationProgress {
    var language: Language?
    var processed: AppEvent?
    var problem: String?

    /// Reads the events since the file was sent; `true` once the text was processed (the transcript files are
    /// written before that event; pasting, or not, follows at once) or something went wrong.
    mutating func read(_ events: [AppEvent]) -> Bool {
        for event in events {
            switch event {
            case let .transcribed(detected, _, _): language = detected
            case .processed:
                processed = event
                return true
            case .noSpeech: problem = "the app heard no speech"
            case let .transcriptionFailed(reason): problem = "transcription failed: \(reason)"
            default: continue
            }
        }
        return problem != nil
    }
}
