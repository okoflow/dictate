import DictateCore
import Foundation
import Observation
import os

@Observable
final class DictationQueue {
    @ObservationIgnored private let transcriber: any Transcriber
    @ObservationIgnored private let processor: TranscriptProcessor
    @ObservationIgnored private let inserter: any TextInserter
    @ObservationIgnored private let clipboard: any Clipboard
    @ObservationIgnored private let history: HistoryModel
    @ObservationIgnored private let settings: SettingsModel
    @ObservationIgnored private let hud: HUDController
    @ObservationIgnored private let continuation: AsyncStream<DictationJob>.Continuation
    private var recentTranscripts = RecentTranscripts()
    @ObservationIgnored private var pendingCount = 0

    var latestTranscript: String? {
        recentTranscripts.latest(at: Date())
    }

    init(
        transcriber: any Transcriber,
        rewriters: PerProvider<any TextRewriter>,
        inserter: any TextInserter,
        clipboard: any Clipboard,
        history: HistoryModel,
        settings: SettingsModel,
        hud: HUDController,
    ) {
        self.transcriber = transcriber
        processor = TranscriptProcessor(rewriters: rewriters)
        self.inserter = inserter
        self.clipboard = clipboard
        self.history = history
        self.settings = settings
        self.hud = hud

        let (jobs, continuation) = AsyncStream.makeStream(of: DictationJob.self)
        self.continuation = continuation

        Task { [weak self] in
            for await job in jobs {
                await self?.run(job)
            }
        }
    }

    func submit(_ job: DictationJob) {
        pendingCount += 1

        hud.setWorking("Transcribing…")
        continuation.yield(job)
    }

    func waitUntilIdle() async {
        await inserter.waitUntilIdle()
    }

    private func run(_ job: DictationJob) async {
        let outcome = await outcome(of: job)

        pendingCount -= 1

        hud.setWorking(pendingCount > 0 ? "Transcribing…" : nil)
        hud.show(outcome.message(for: job.cloud.provider))
    }

    private func outcome(of job: DictationJob) async -> DictationOutcome {
        do {
            guard let transcript = try await transcriber.transcribe(
                job.samples,
                in: job.language,
                vocabulary: job.vocabulary.promptTerms,
            ) else {
                Logger.dictation.info("No speech in the recording")

                return .noSpeech
            }

            if job.mode.isCloud {
                hud.setWorking("Polishing with \(job.cloud.provider.title)…")
            }

            let processed = await processor.process(
                transcript.text,
                language: transcript.language,
                mode: job.mode,
                cloud: job.cloud,
                vocabulary: job.vocabulary,
            )
            log(transcript, processed)

            return await deliver(processed, for: job)
        } catch {
            Logger.dictation.error("Transcription failed: \(error.localizedDescription, privacy: .public)")

            return .failed(error.localizedDescription)
        }
    }

    private func deliver(_ processed: ProcessedText, for job: DictationJob) async -> DictationOutcome {
        guard !processed.text.isEmpty else { return .noSpeech }

        recentTranscripts.remember(processed.text, at: Date())

        guard job.pastes else {
            clipboard.copy(processed.text)
            remember(processed, for: job)

            return .copied(processed)
        }

        switch await inserter.insert(processed.text, into: job.target, releasing: job.key) {
        case .pasted:
            remember(processed, for: job)

            return .pasted(processed)

        case .skipped(.secureField):
            return .blockedInPasswordField

        case .skipped:
            clipboard.copy(processed.text)
            remember(processed, for: job)

            return .copied(processed)
        }
    }

    private func remember(_ processed: ProcessedText, for job: DictationJob) {
        guard settings.settings.keepsHistory else { return }

        history.add(DictationHistory.Entry(
            date: Date(),
            text: processed.text,
            mode: processed.appliedMode,
            app: job.target.bundleIdentifier,
        ))
    }

    private func log(_ transcript: Transcript, _ processed: ProcessedText) {
        let fallback = processed.fallback?.rawValue ?? "none"

        Logger.dictation.info(
            """
            Recognized \(transcript.text.count) characters of \(transcript.language.code, privacy: .public) \
            in \(transcript.detectionDuration + transcript.decodingDuration, privacy: .public); \
            mode \(processed.requestedMode.rawValue, privacy: .public) \
            ran as \(processed.appliedMode.rawValue, privacy: .public), \
            fallback \(fallback, privacy: .public), cloud \(processed.contactedCloud), snippet \(processed.isSnippet)
            """,
        )
    }
}
