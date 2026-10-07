import DictateCore
import Foundation
@preconcurrency import WhisperKit

enum TranscriberError: LocalizedError {
    case notLoaded
    case modelMissing(String)
    case tokenizerMissing
    case languageTokensMissing

    var errorDescription: String? {
        switch self {
        case .notLoaded: "the model is not loaded"
        case let .modelMissing(name): "the model \(name) is not downloaded"
        case .tokenizerMissing: "the model has no tokenizer"
        case .languageTokensMissing: "the tokenizer has no tokens for ru / en / ko"
        }
    }
}

/// Speech to text with WhisperKit. All of WhisperKit stays inside this actor (its types are not
/// `Sendable`), and recordings are transcribed one at a time, in the order they arrive.
public actor Transcriber {
    /// Whisper's sample rate; recordings are already converted to it.
    public static let sampleRate = 16000.0
    /// Audio longer than Whisper's 30 s window is split at pauses by WhisperKit's voice-activity chunker.
    private static let windowSamples = 30 * 16000

    private let model: String
    private let baseDirectory: URL
    private var kit: WhisperKit?
    private let usesStylePrompt: Bool
    /// Whisper reads at most 224 prompt tokens; the newest ones are kept.
    private static let maximumPromptTokens = 200
    private var busy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// `usesStylePrompt: false` exists for the bench, which compares output with and without it.
    public init(
        model: String = ModelStore.defaultModel,
        baseDirectory: URL = ModelStore.defaultBaseDirectory,
        usesStylePrompt: Bool = true
    ) {
        self.model = model
        self.baseDirectory = baseDirectory
        self.usesStylePrompt = usesStylePrompt
    }

    /// Downloads `model` and its tokenizer into `baseDirectory` (skipping what is already there; an
    /// interrupted download resumes) and then writes the completion marker; `progress` is 0...1.
    public static func download(
        model: String,
        into baseDirectory: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        _ = try await WhisperKit.download(
            variant: model,
            downloadBase: baseDirectory,
            from: ModelStore.repository
        ) { progress($0.fractionCompleted) }
        if ModelStore.tokenizerFile(for: model, in: baseDirectory) != nil {
            _ = try await ModelUtilities.loadTokenizer(for: .largev3, tokenizerFolder: baseDirectory)
        }
        try ModelStore.markComplete(model, in: baseDirectory)
    }

    /// Loads the downloaded model and returns how long that took. The first load on a machine makes
    /// Core ML compile the model for its chip, which takes about a minute; later loads take seconds.
    /// Never downloads anything: `isInstalled` requires the model and its tokenizer to be on disk.
    public func load() async throws -> Double {
        guard ModelStore.isInstalled(model, in: baseDirectory) else { throw TranscriberError.modelMissing(model) }
        let start = ContinuousClock.now
        let config = WhisperKitConfig(
            model: model,
            downloadBase: baseDirectory,
            modelFolder: ModelStore.folder(of: model, in: baseDirectory).path,
            tokenizerFolder: baseDirectory,
            verbose: false,
            logLevel: .none,
            load: true,
            download: false
        )
        let loaded = try await WhisperKit(config)
        guard let tokenizer = loaded.tokenizer else { throw TranscriberError.tokenizerMissing }
        let tokens = Set(Language.allCases.compactMap { tokenizer.convertTokenToId("<|\($0.rawValue)|>") })
        guard tokens.count == Language.allCases.count else { throw TranscriberError.languageTokensMissing }
        loaded.tokenizer = RestrictedTokenizer(base: tokenizer, allLanguageTokens: tokens)
        kit = loaded
        return (ContinuousClock.now - start).seconds
    }

    /// Turns 16 kHz mono `samples` into text in `language`, or in the most probable of ru / en / ko
    /// when `language` is `nil`. `terms` (the personal dictionary) go into Whisper's prompt after the style sentence. Returns `nil` when there is nothing to transcribe: the audio has no
    /// speech in it (`SpeechGate`), or the result looks made up (`TranscriptFilter`). WhisperKit's own
    /// `noSpeechThreshold` is not used: its no-speech probability is always 0.
    public func transcribe(samples: [Float], language: Language?, terms: [String] = []) async throws -> Transcript? {
        guard SpeechGate.decide(samples: samples, sampleRate: Self.sampleRate) == .transcribe else { return nil }
        guard let kit else { throw TranscriberError.notLoaded }
        await acquire()
        defer { release() }

        var detectSeconds = 0.0
        var probability: Double?
        var chosen = language
        if chosen == nil {
            let start = ContinuousClock.now
            let detected = try await kit.detectLangauge(audioArray: samples)
            detectSeconds = (ContinuousClock.now - start).seconds
            let picked = Language.pick(from: detected.langProbs)
            chosen = picked?.language ?? .en
            probability = picked.map { exp(Double($0.probability)) }
        }
        guard let chosen else { return nil }
        let start = ContinuousClock.now
        let options = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: chosen.rawValue,
            usePrefillPrompt: true,
            detectLanguage: false,
            skipSpecialTokens: true,
            promptTokens: promptTokens(for: chosen, terms: terms, kit: kit),
            chunkingStrategy: samples.count > Self.windowSamples ? .vad : nil
        )
        let results = try await kit.transcribe(audioArray: samples, decodeOptions: options)
        guard let text = Self.acceptedText(of: results, language: chosen) else { return nil }
        return Transcript(
            text: text,
            language: chosen,
            languageProbability: probability,
            detectSeconds: detectSeconds,
            transcribeSeconds: (ContinuousClock.now - start).seconds
        )
    }

    /// `WhisperPrompt` as tokens; `nil` when the prompt is off (the bench's comparison) or empty.
    private func promptTokens(for language: Language, terms: [String], kit: WhisperKit) -> [Int]? {
        guard usesStylePrompt, let tokenizer = kit.tokenizer, let text = WhisperPrompt.text(for: language, terms: terms) else {
            return nil
        }
        let firstSpecial = tokenizer.specialTokens.specialTokenBegin
        let tokens = tokenizer.encode(text: " " + text).filter { $0 < firstSpecial }
        return tokens.isEmpty ? nil : Array(tokens.suffix(Self.maximumPromptTokens))
    }

    private static func keeps(_ segment: TranscriptionSegment) -> Bool {
        TranscriptFilter.keepsSegment(
            averageLogProbability: Double(segment.avgLogprob), compressionRatio: Double(segment.compressionRatio)
        )
    }

    /// The text of the segments worth keeping (each judged on its own), unless nothing is left or what is
    /// left is a known stock phrase. A text with no capitals and no punctuation gets its first letter capitalised.
    private static func acceptedText(of results: [TranscriptionResult], language: Language) -> String? {
        let segments = results.flatMap(\.segments)
        let joined = segments.isEmpty
            ? results.map(\.text).joined(separator: " ")
            : segments
            .filter { keeps($0) }
            .map(\.text).joined()
        let text = joined.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !TranscriptFilter.isKnownHallucination(text, language: language) else { return nil }
        return TranscriptFilter.capitalisedIfUnstyled(text, language: language)
    }

    // MARK: One at a time

    /// The actor releases its isolation at every `await`, so two recordings would otherwise be
    /// inside WhisperKit at once. Waiters are resumed in the order they arrived.
    private func acquire() async {
        if busy {
            await withCheckedContinuation { waiters.append($0) }
        } else {
            busy = true
        }
    }

    private func release() {
        if waiters.isEmpty {
            busy = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}

private extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
