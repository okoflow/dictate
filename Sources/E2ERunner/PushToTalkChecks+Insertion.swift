import AppKit
import ApplicationServices
import DictateCore
import E2ESupport
import Foundation

/// The M3 check: speak a fixture and the text appears in the focused field.
extension PushToTalkChecks {
    private static let existingText = "Existing text."

    /// With TestPad in front holding "Existing text.", hold right Option while `ru-plain-2` plays into
    /// BlackHole and release. TestPad must then hold the old text, a space and a Russian transcript close
    /// to the manifest text (identical to the saved transcript file), and the clipboard must be what it
    /// was before.
    func dictateIntoTestPad() -> Outcome {
        run {
            let environment = try session.environment()
            let expected = try fixtureText(id: "ru-plain-2")
            let wav = fixturesDirectory.appendingPathComponent("generated/ru-plain-2.wav")
            try startTestPadWithExistingText()
            try waitForTranscriptionsToFinish()
            let playback = try prepareFixturePlayback(of: wav, on: environment.blackHole)

            let original = ClipboardSnapshot.take()
            defer { original.restore() }
            let marker = "clipboard-before-\(UUID().uuidString)"
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(marker, forType: .string)

            let baseline = log.baseline()
            _ = try session.capture(playing: playback, silence: 0) {
                // The paste goes to whatever is in front when the text is ready; it must be TestPad.
                guard testPadIsFrontmost() else {
                    throw Verdict.blocked("TestPad is not in front: do not switch apps during the suite")
                }
            }
            try requireInsertion(since: baseline)
            let rate = try checkInsertedText(against: expected)
            guard NSPasteboard.general.string(forType: .string) == marker else {
                throw Verdict.fail("the clipboard was not restored")
            }
            return .measured(String(format: "inserted after the old text, error %.1f %%, clipboard restored", rate * 100))
        }
    }

    /// TestPad in front, with `existingText` and the caret after it.
    private func startTestPadWithExistingText() throws {
        let element = try prepareTestPad()
        guard Accessibility.setValue(Self.existingText, of: element),
              waitUntil(timeout: 3, { testPadState()?.text == Self.existingText }),
              Accessibility.setCaret(at: Self.existingText.utf16.count, of: element)
        else {
            throw Verdict.fail("cannot put the starting text into TestPad")
        }
    }

    /// TestPad holds the old text, one space, and the transcript; returns the transcript's error rate.
    private func checkInsertedText(against expected: Fixture) throws -> Double {
        let typed = testPadState()?.text ?? "?"
        guard typed.hasPrefix(Self.existingText + " ") else {
            throw Verdict.fail("TestPad holds \"\(typed)\", expected the old text, a space and the transcript")
        }
        let added = String(typed.dropFirst(Self.existingText.count + 1))
        let rate = TextMetrics.cer(
            reference: expected.text, alternatives: expected.alternatives, hypothesis: added, language: .ru
        )
        let limit = Self.maximumCharacterErrorRate
        guard rate <= limit else {
            throw Verdict.fail(String(format: "the inserted text is off by %.0f %% (limit %.0f %%)", rate * 100, limit * 100))
        }
        guard latestTranscript() == added else { throw Verdict.fail("the transcript file differs from the inserted text") }
        return rate
    }

    /// Waits for the `inserted` event that ends the recording made after `baseline`; any other ending fails.
    private func requireInsertion(since baseline: EventLog.Baseline) throws {
        let outcome = try session.wait(since: baseline, timeout: 60) { event -> Result<Void, EventFailure>? in
            switch event {
            case .inserted: .success(())
            case let .insertionSkipped(reason): .failure(EventFailure(description: "insertion skipped: \(reason)"))
            case .noSpeech: .failure(EventFailure(description: "the app heard no speech"))
            case let .transcriptionFailed(reason): .failure(EventFailure(description: "transcription failed: \(reason)"))
            default: nil
            }
        }
        guard let outcome else {
            throw Verdict.fail("no insertion within 60 s of the release: \(log.newEvents(since: baseline))")
        }
        if case let .failure(failure) = outcome {
            throw Verdict.fail("\(failure)")
        }
    }
}
