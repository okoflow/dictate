import AppKit
import DictateCore
import Foundation

/// The M2 check: speak a fixture, and the text lands on the clipboard.
extension PushToTalkChecks {
    static let maximumCharacterErrorRate = 0.15
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    /// Holds right Option while `ru-plain-2` plays into BlackHole, then expects a Russian transcript on
    /// the clipboard that is close to the manifest text, identical to the saved transcript file, and
    /// marked so clipboard managers skip it. The clipboard the user had before is put back.
    func dictateFixtureToClipboard() -> Outcome {
        run {
            let environment = try session.environment()
            let expected = try fixtureText(id: "ru-plain-2")
            let wav = fixturesDirectory.appendingPathComponent("generated/ru-plain-2.wav")
            // Earlier checks left recordings that are still being recognised; their results must not
            // land on the clipboard between the snapshot and this check's own. The playback engine is
            // started only after that wait: an engine left idle for seconds can lose its route.
            try waitForTranscriptionsToFinish()
            let playback = try prepareFixturePlayback(of: wav, on: environment.blackHole)

            let clipboard = ClipboardSnapshot.take()
            defer { clipboard.restore() }
            let baseline = log.baseline()
            _ = try session.capture(playing: playback, silence: 0)
            let result = try transcriptionResult(since: baseline)
            guard result.language == .ru else { throw Verdict.fail("expected language ru, the app detected \(result.language)") }

            let text = try clipboardText(matching: result)
            let rate = TextMetrics.cer(
                reference: expected.text, alternatives: expected.alternatives, hypothesis: text, language: .ru
            )
            guard rate <= Self.maximumCharacterErrorRate else {
                let limit = Self.maximumCharacterErrorRate * 100
                throw Verdict.fail(String(format: "clipboard text is off by %.0f %% (limit %.0f %%)", rate * 100, limit))
            }
            guard latestTranscript() == text else { throw Verdict.fail("the transcript file differs from the clipboard") }
            return .measured(String(format: "language ru, error %.1f %%, recognised in %.2f s", rate * 100, result.seconds))
        }
    }

    // MARK: Helpers

    func fixtureText(id: String) throws -> Fixture {
        let manifest = try Fixture.load(from: fixturesDirectory.appendingPathComponent("manifest.json"))
        guard let fixture = manifest.first(where: { $0.id == id }) else { throw Verdict.fail("\(id) is not in the manifest") }
        return fixture
    }

    /// Waits for the app to say what became of the recording made after `baseline`.
    private func transcriptionResult(since baseline: EventLog.Baseline) throws -> Transcribed {
        guard let outcome = try session.wait(since: baseline, timeout: 60, Self.transcriptionOutcome) else {
            throw Verdict.fail("no transcription result within 60 s of the release: \(log.newEvents(since: baseline))")
        }
        switch outcome {
        case let .success(result): return result
        case let .failure(failure): throw Verdict.fail("the app did not transcribe: \(failure)")
        }
    }

    /// The clipboard text, after checking it is what the event describes and is hidden from clipboard managers.
    private func clipboardText(matching result: Transcribed) throws -> String {
        let pasteboard = NSPasteboard.general
        guard let text = pasteboard.string(forType: .string) else { throw Verdict.fail("the clipboard holds no text") }
        guard text.count == result.characters else {
            throw Verdict.fail("the event says \(result.characters) characters, the clipboard has \(text.count)")
        }
        let types = Set(pasteboard.types ?? [])
        guard types.contains(Self.concealedType), types.contains(Self.transientType) else {
            throw Verdict.fail("the clipboard item is not marked transient and concealed")
        }
        return text
    }

    struct Transcribed {
        let language: Language
        let characters: Int
        let seconds: Double
    }

    /// `transcribed` is success; anything else that ends a recording's recognition is a failure to report.
    static func transcriptionOutcome(_ event: AppEvent) -> Result<Transcribed, EventFailure>? {
        switch event {
        case let .transcribed(language, characters, seconds):
            .success(Transcribed(language: language, characters: characters, seconds: seconds))
        case .noSpeech:
            .failure(EventFailure(description: "the app heard no speech"))
        case let .transcriptionFailed(reason):
            .failure(EventFailure(description: "transcription failed: \(reason)"))
        default:
            nil
        }
    }

    struct EventFailure: Error, CustomStringConvertible {
        let description: String
    }

    /// Every finished recording has produced exactly one result event.
    func waitForTranscriptionsToFinish(timeout: TimeInterval = 60) throws {
        let settled = waitUntil(timeout: timeout, interval: 0.25) {
            let events = log.events
            let recorded = events.filter {
                switch $0 {
                case .recordingFinished, .fileSubmitted: true
                default: false
                }
            }.count
            let answered = events.filter { Self.transcriptionOutcome($0) != nil }.count
            return recorded == answered
        }
        guard settled else { throw Verdict.fail("earlier recordings were still being recognised after \(Int(timeout)) s") }
    }

    /// The text of the highest-numbered `<n>.txt` in the transcript directory.
    func latestTranscript() -> String? {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: transcriptDirectory.path)) ?? []
        let newest = names.compactMap { name in name.hasSuffix(".txt") ? Int(name.dropLast(4)) : nil }.max()
        return newest.flatMap {
            try? String(contentsOf: transcriptDirectory.appendingPathComponent("\($0).txt"), encoding: .utf8)
        }
    }
}

/// The general pasteboard's items, so a check can leave the user's clipboard as it found it.
struct ClipboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]

    static func take() -> ClipboardSnapshot {
        let items = NSPasteboard.general.pasteboardItems ?? []
        return ClipboardSnapshot(items: items.map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in item.data(forType: type).map { (type, $0) } })
        })
    }

    func restore() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let restored = items.map { contents -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in contents {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(restored)
    }
}
