import DictateCore
import Foundation
import Transcription

/// Turns finished recordings into text in the chosen mode and pastes it, one at a time in the order they were
/// made, so a second dictation started while the first is still being recognised does not overtake it.
@MainActor
final class TranscriptionPipeline {
    private struct Job {
        let samples: [Float]
        let language: Language?
        let mode: Mode
        let vocabulary: Vocabulary
        let target: FocusSnapshot
    }

    private let transcriber: Transcriber
    private let options: LaunchOptions
    private let eventLog: EventLogWriter
    private let status: Overlay
    private let inserter: Inserter
    private let insertion: InsertionSettings
    private let lastTranscript: LastTranscript
    private let history: HistoryStore
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
        status: Overlay,
        inserter: Inserter,
        insertion: InsertionSettings,
        lastTranscript: LastTranscript,
        history: HistoryStore,
        recordingPillIsVisible: @escaping @MainActor () -> Bool
    ) {
        self.transcriber = transcriber
        self.options = options
        self.eventLog = eventLog
        self.status = status
        self.inserter = inserter
        self.insertion = insertion
        self.lastTranscript = lastTranscript
        self.history = history
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

    /// Waits for a paste in progress (and its clipboard restore) to finish.
    func finishPendingInsertions() async {
        await inserter.waitUntilIdle()
    }

    /// Queues `samples`; `language`, `mode` and `vocabulary` are the choices at the moment of the recording,
    /// `target` the focus at the moment the key went down.
    func submit(samples: [Float], language: Language?, mode: Mode, vocabulary: Vocabulary, target: FocusSnapshot) {
        pending += 1
        jobs.yield(Job(samples: samples, language: language, mode: mode, vocabulary: vocabulary, target: target))
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
            let terms = job.vocabulary.promptTerms
            if let transcript = try await transcriber.transcribe(samples: job.samples, language: job.language, terms: terms) {
                let start = ContinuousClock.now
                let processed = await apply(job, to: transcript)
                let seconds = (ContinuousClock.now - start) / .seconds(1)
                let delivered = await deliver(processed, of: transcript, processingSeconds: seconds, target: job.target)
                message = processed.fallback.map { "\(delivered)\n\($0.message)" } ?? delivered
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

    /// The dictionary's spellings, then a whole-dictation snippet as it is, or the mode followed by the spellings
    /// again (an LLM may undo them) and the snippets inside the text.
    private func apply(_ job: Job, to transcript: Transcript) async -> ProcessedText {
        let corrected = job.vocabulary.correcting(transcript.text)
        if let snippet = job.vocabulary.wholeSnippet(for: corrected) {
            eventLog.log(.snippetExpanded)
            return ProcessedText(text: snippet, requested: job.mode, applied: .raw, fallback: nil, contactedCloud: false)
        }
        let rewriter = job.mode.isCloud ? AnthropicRewriter.current(options: options) : nil
        let processed = await ModeProcessor(rewriter: rewriter).process(corrected, mode: job.mode, language: transcript.language)
        return processed.with(text: job.vocabulary.expandingSnippets(in: job.vocabulary.correcting(processed.text)))
    }

    /// Hands the processed text on: pasted into the focused field, or (setting off, or the paste was not safe) on
    /// the clipboard. The transcript files (`<n>.txt` delivered, `<n>.raw.txt` recognised), when asked for, are
    /// written before the events, so whoever waits for an event finds them in place. Returns what to tell the user.
    private func deliver(
        _ processed: ProcessedText, of transcript: Transcript, processingSeconds: Double, target: FocusSnapshot
    ) async -> String {
        let text = processed.text
        lastTranscript.remember(text)
        history.add(.init(date: Date(), text: text, mode: processed.applied, app: target.bundleIdentifier))
        let inserting = insertion.isEnabled && !options.clipboardOnly
        if !inserting {
            Clipboard.copy(text)
        }
        if let directory = options.transcriptDirectory {
            savedTranscripts += 1
            let url = URL(fileURLWithPath: directory)
            try? TranscriptStore.save(transcript.text, name: "\(savedTranscripts).raw", in: url)
            try? TranscriptStore.save(text, name: "\(savedTranscripts)", in: url)
        }
        eventLog.log(.transcribed(language: transcript.language, characters: transcript.text.count, seconds: transcript.seconds))
        eventLog.log(.processed(
            mode: processed.requested, applied: processed.applied, fallback: processed.fallback,
            cloud: processed.contactedCloud, characters: text.count, seconds: processingSeconds
        ))
        guard !text.isEmpty else { return "Didn't catch that" }
        guard inserting else { return text }

        if let only = options.insertOnlyInto, target.bundleIdentifier != only {
            eventLog.log(.insertionSkipped(.notAllowed))
            return text
        }
        switch await inserter.insert(text, target: target) {
        case .inserted:
            return text
        case .skipped(.secureField):
            // Not copied either: a password field is where the text must not go, or linger.
            return "Not typed into a password field (menu: Copy last transcript)"
        case .skipped:
            Clipboard.copy(text)
            return "Copied — ⌘V to paste"
        }
    }
}
