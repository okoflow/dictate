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
        let target: FocusSnapshot
    }

    private let transcriber: Transcriber
    private let options: LaunchOptions
    private let eventLog: EventLogWriter
    private let status: StatusOverlay
    private let inserter: Inserter
    private let insertion: InsertionSettings
    private let lastTranscript: LastTranscript
    private let recordingPillIsVisible: @MainActor () -> Bool
    private let jobs: AsyncStream<Job>.Continuation
    private var pending = 0
    /// What to tell the user, oldest first. Each entry gets its full time on the pill; entries wait while
    /// the recording pill is up or another message is still being read.
    private var messages: [String] = []
    private var savedTranscripts = 0

    init(
        transcriber: Transcriber,
        options: LaunchOptions,
        eventLog: EventLogWriter,
        status: StatusOverlay,
        inserter: Inserter,
        insertion: InsertionSettings,
        lastTranscript: LastTranscript,
        recordingPillIsVisible: @escaping @MainActor () -> Bool
    ) {
        self.transcriber = transcriber
        self.options = options
        self.eventLog = eventLog
        self.status = status
        self.inserter = inserter
        self.insertion = insertion
        self.lastTranscript = lastTranscript
        self.recordingPillIsVisible = recordingPillIsVisible
        let (stream, continuation) = AsyncStream.makeStream(of: Job.self)
        jobs = continuation
        status.onMessageFinished = { [weak self] in self?.presentNext() }
        Task { [weak self] in
            for await job in stream {
                await self?.process(job)
            }
        }
    }

    /// Queues `samples`; `language` is the menu choice at the moment of the recording, `target` the focus
    /// at the moment the key went down.
    func submit(samples: [Float], language: Language?, target: FocusSnapshot) {
        pending += 1
        jobs.yield(Job(samples: samples, language: language, target: target))
        presentNext()
    }

    /// Called when the recording pill goes away: whatever waited behind it can be shown now.
    func recordingPillHidden() {
        presentNext()
    }

    /// The next message if there is one, else the spinner while work is queued. Never over the recording
    /// pill, and never over a message that is still being read.
    private func presentNext() {
        guard !recordingPillIsVisible(), !status.isShowingMessage else { return }
        if messages.isEmpty {
            if pending > 0 {
                status.showTranscribing()
            }
        } else {
            status.show(message: messages.removeFirst())
        }
    }

    private func process(_ job: Job) async {
        let message: String
        do {
            if let transcript = try await transcriber.transcribe(samples: job.samples, language: job.language) {
                message = await deliver(transcript, target: job.target)
            } else {
                eventLog.log(.noSpeech)
                message = "Didn't catch that"
            }
        } catch {
            eventLog.log(.transcriptionFailed(error.localizedDescription))
            message = "Transcription failed"
        }
        pending -= 1
        messages.append(message)
        presentNext()
    }

    /// Hands the text on: pasted into the focused field, or (setting off, or the paste was not safe) on the
    /// clipboard. The transcript file, when asked for, is written before the event, so whoever waits for
    /// the event finds it in place. Returns what to tell the user.
    private func deliver(_ transcript: Transcript, target: FocusSnapshot) async -> String {
        lastTranscript.remember(transcript.text)
        let inserting = insertion.isEnabled && !options.clipboardOnly
        if !inserting {
            Clipboard.copy(transcript.text)
        }
        if let directory = options.transcriptDirectory {
            savedTranscripts += 1
            try? TranscriptStore.save(transcript.text, number: savedTranscripts, in: URL(fileURLWithPath: directory))
        }
        eventLog.log(.transcribed(language: transcript.language, characters: transcript.text.count, seconds: transcript.seconds))
        guard inserting else { return transcript.text }

        switch await inserter.insert(transcript.text, target: target) {
        case .inserted:
            return transcript.text
        case .skipped(.secureField):
            // Not copied either: a password field is where the text must not go, or linger.
            return "Not typed into a password field (menu: Copy last transcript)"
        case .skipped:
            Clipboard.copy(transcript.text)
            return "Copied — ⌘V to paste"
        }
    }
}
