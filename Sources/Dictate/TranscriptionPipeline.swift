import DictateCore
import Foundation
import Transcription

/// Turns finished recordings into clipboard text, one at a time in the order they were made, so a
/// second dictation started while the first is still being recognised does not overtake it.
@MainActor
final class TranscriptionPipeline {
    private struct Job {
        let samples: [Float]
        let language: Language?
    }

    private let transcriber: Transcriber
    private let options: LaunchOptions
    private let eventLog: EventLogWriter
    private let status: StatusOverlay
    private let recordingPillIsVisible: @MainActor () -> Bool
    private let jobs: AsyncStream<Job>.Continuation
    private var pending = 0
    private var savedTranscripts = 0

    init(
        transcriber: Transcriber,
        options: LaunchOptions,
        eventLog: EventLogWriter,
        status: StatusOverlay,
        recordingPillIsVisible: @escaping @MainActor () -> Bool
    ) {
        self.transcriber = transcriber
        self.options = options
        self.eventLog = eventLog
        self.status = status
        self.recordingPillIsVisible = recordingPillIsVisible
        let (stream, continuation) = AsyncStream.makeStream(of: Job.self)
        jobs = continuation
        Task { [weak self] in
            for await job in stream {
                await self?.process(job)
            }
        }
    }

    /// Queues `samples`; `language` is the menu choice at the moment of the recording.
    func submit(samples: [Float], language: Language?) {
        pending += 1
        jobs.yield(Job(samples: samples, language: language))
        showSpinnerIfFree()
    }

    /// Called when the recording pill goes away: the spinner comes back if work is still queued.
    func recordingPillHidden() {
        showSpinnerIfFree()
    }

    private func showSpinnerIfFree() {
        if pending > 0, !recordingPillIsVisible() {
            status.showTranscribing()
        }
    }

    private func process(_ job: Job) async {
        showSpinnerIfFree()
        let message: String
        do {
            if let transcript = try await transcriber.transcribe(samples: job.samples, language: job.language) {
                deliver(transcript)
                message = transcript.text
            } else {
                eventLog.log(.noSpeech)
                message = "Didn't catch that"
            }
        } catch {
            eventLog.log(.transcriptionFailed(String(describing: error)))
            message = "Transcription failed"
        }
        pending -= 1
        if recordingPillIsVisible() {
            status.hide()
        } else {
            status.show(message: message)
        }
    }

    /// The clipboard and the transcript file are written before the event, so whoever waits for the
    /// event finds both in place.
    private func deliver(_ transcript: Transcript) {
        Clipboard.copy(transcript.text)
        if let directory = options.transcriptDirectory {
            savedTranscripts += 1
            try? TranscriptStore.save(transcript.text, number: savedTranscripts, in: URL(fileURLWithPath: directory))
        }
        eventLog.log(.transcribed(language: transcript.language, characters: transcript.text.count, seconds: transcript.seconds))
    }
}
