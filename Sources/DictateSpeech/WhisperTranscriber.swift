@preconcurrency internal import WhisperKit
import DictateCore
import Foundation

package actor WhisperTranscriber: Transcriber {
    private static let windowSampleCount = 30 * Int(SpeechAudio.sampleRate)
    private static let maximumPromptTokens = 200

    package nonisolated let modelDirectory: URL

    private let files: SpeechModelFiles
    private var whisper: WhisperKit?
    private var isTranscribing = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    package init(model: String = SpeechModelFiles.defaultModel, baseDirectory: URL = SpeechModelFiles.defaultBaseDirectory) {
        files = SpeechModelFiles(model: model, baseDirectory: baseDirectory)
        modelDirectory = files.folder
    }

    private static func acceptedText(of results: [TranscriptionResult], language: Language, prompt: String?) -> String? {
        let segments = results.flatMap(\.segments)
        let kept = segments.isEmpty
            ? results.map(\.text).joined(separator: " ")
            : segments.filter(isConfident).map(\.text).joined()
        let text = kept.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty, !HallucinationFilter.isHallucination(text, in: language, prompt: prompt) else { return nil }

        return text.capitalizedIfUnstyled(in: language)
    }

    private static func isConfident(_ segment: TranscriptionSegment) -> Bool {
        HallucinationFilter.keepsSegment(
            averageLogProbability: Double(segment.avgLogprob),
            compressionRatio: Double(segment.compressionRatio),
        )
    }

    package func isModelInstalled() -> Bool {
        files.isInstalled
    }

    package func downloadModel(progress: @escaping @Sendable (Double) -> Void) async throws {
        try FileManager.default.createDirectory(at: files.baseDirectory, withIntermediateDirectories: true)

        _ = try await WhisperKit.download(
            variant: files.model,
            downloadBase: files.baseDirectory,
            from: SpeechModelFiles.repository,
        ) { progress($0.fractionCompleted) }

        if files.tokenizerFile != nil {
            _ = try await ModelUtilities.loadTokenizer(for: .largev3, tokenizerFolder: files.baseDirectory)
        }

        try files.markComplete()
    }

    package func loadModel(for languages: [Language]) async throws -> Duration {
        guard files.isInstalled else { throw TranscriberError.modelMissing(files.model) }

        whisper = nil

        let start = ContinuousClock.now
        let loaded = try await WhisperKit(configuration())
        loaded.tokenizer = try restrictedTokenizer(of: loaded, to: languages)
        whisper = loaded

        return ContinuousClock.now - start
    }

    package func deleteModel() {
        whisper = nil

        files.remove()
    }

    package func transcribe(_ samples: [Float], in language: Language?, vocabulary: [String]) async throws -> Transcript? {
        guard SpeechGate.containsSpeech(samples, sampleRate: SpeechAudio.sampleRate) else { return nil }
        guard let whisper else { throw TranscriberError.notLoaded }

        await waitForTurn()
        defer { finishTurn() }

        let detectionStart = ContinuousClock.now
        let spoken = try await resolvedLanguage(language, of: samples, with: whisper)

        let decodingStart = ContinuousClock.now
        let prompt = WhisperPrompt.text(for: spoken, vocabulary: vocabulary)
        let options = decodingOptions(for: spoken, samples: samples, prompt: prompt, tokenizer: whisper.tokenizer)
        let results = try await whisper.transcribe(audioArray: samples, decodeOptions: options)

        guard let text = Self.acceptedText(of: results, language: spoken, prompt: prompt) else { return nil }

        return Transcript(
            text: text,
            language: spoken,
            detectionDuration: decodingStart - detectionStart,
            decodingDuration: ContinuousClock.now - decodingStart,
        )
    }

    package func transcribeFile(
        _ samples: [Float],
        in language: Language?,
        progress: @Sendable (Double) -> Void,
    ) async throws -> TimedTranscript? {
        guard let whisper else { throw TranscriberError.notLoaded }

        let chunks = try await VADAudioChunker().chunkAll(
            audioArray: samples,
            maxChunkLength: Self.windowSampleCount,
            decodeOptions: nil,
        )
        var spoken = language
        var segments: [TimedSegment] = []

        for (index, chunk) in chunks.enumerated() {
            try Task.checkCancellation()

            if SpeechGate.containsSpeech(chunk.audioSamples, sampleRate: SpeechAudio.sampleRate) {
                await waitForTurn()
                defer { finishTurn() }

                let chunkLanguage = try await resolvedLanguage(spoken, of: chunk.audioSamples, with: whisper)
                spoken = chunkLanguage
                segments += try await timedSegments(of: chunk, in: chunkLanguage, with: whisper)
            }

            progress(Double(index + 1) / Double(chunks.count))
        }

        guard let spoken, !segments.isEmpty else { return nil }

        return TimedTranscript(language: spoken, segments: segments)
    }

    private func timedSegments(
        of chunk: AudioChunk,
        in language: Language,
        with whisper: WhisperKit,
    ) async throws -> [TimedSegment] {
        var options = decodingOptions(for: language, samples: chunk.audioSamples, prompt: nil, tokenizer: whisper.tokenizer)
        options.chunkingStrategy = nil

        let results = try await whisper.transcribe(audioArray: chunk.audioSamples, decodeOptions: options)
        let offset = Double(chunk.seekOffsetIndex) / SpeechAudio.sampleRate
        let segments = results.flatMap(\.segments).filter(Self.isConfident).compactMap { segment -> TimedSegment? in
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }

            return TimedSegment(start: offset + Double(segment.start), end: offset + Double(segment.end), text: text)
        }
        let text = segments.map(\.text).joined(separator: " ")

        return HallucinationFilter.isHallucination(text, in: language, prompt: nil) ? [] : segments
    }

    private func configuration() -> WhisperKitConfig {
        WhisperKitConfig(
            model: files.model,
            downloadBase: files.baseDirectory,
            modelFolder: files.folder.path,
            tokenizerFolder: files.baseDirectory,
            verbose: false,
            logLevel: .none,
            load: true,
            download: false,
        )
    }

    private func restrictedTokenizer(of whisper: WhisperKit, to languages: [Language]) throws -> any WhisperTokenizer {
        guard let tokenizer = whisper.tokenizer else { throw TranscriberError.tokenizerMissing }

        let tokens = Set(languages.compactMap { tokenizer.convertTokenToId("<|\($0.code)|>") })
        guard !tokens.isEmpty, tokens.count == languages.count else { throw TranscriberError.languageTokensMissing }

        return LanguageRestrictedTokenizer(base: tokenizer, allLanguageTokens: tokens)
    }

    private func resolvedLanguage(_ language: Language?, of samples: [Float], with whisper: WhisperKit) async throws -> Language {
        if let language {
            return language
        }

        let detection = try await whisper.detectLangauge(audioArray: samples)

        return Language(rawValue: detection.language) ?? .english
    }

    private func decodingOptions(
        for language: Language,
        samples: [Float],
        prompt: String?,
        tokenizer: (any WhisperTokenizer)?,
    ) -> DecodingOptions {
        var options = DecodingOptions()
        options.language = language.code
        options.detectLanguage = false
        options.skipSpecialTokens = true
        options.promptTokens = promptTokens(for: prompt, tokenizer: tokenizer)
        options.chunkingStrategy = samples.count > Self.windowSampleCount ? .vad : nil

        return options
    }

    private func promptTokens(for prompt: String?, tokenizer: (any WhisperTokenizer)?) -> [Int]? {
        guard let prompt, let tokenizer else { return nil }

        let firstSpecialToken = tokenizer.specialTokens.specialTokenBegin
        let tokens = tokenizer.encode(text: " " + prompt).filter { $0 < firstSpecialToken }

        return tokens.isEmpty ? nil : Array(tokens.suffix(Self.maximumPromptTokens))
    }

    private func waitForTurn() async {
        guard isTranscribing else {
            isTranscribing = true

            return
        }

        await withCheckedContinuation { waiters.append($0) }
    }

    private func finishTurn() {
        if waiters.isEmpty {
            isTranscribing = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}
