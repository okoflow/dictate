import DictateCore
import Foundation
@preconcurrency import WhisperKit

enum TranscriberError: Error, CustomStringConvertible {
    case notLoaded
    case modelMissing(String)
    case languageTokensMissing

    var description: String {
        switch self {
        case .notLoaded: "the model is not loaded"
        case let .modelMissing(name): "the model \(name) is not downloaded"
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
    private var busy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init(model: String = ModelStore.defaultModel, baseDirectory: URL = ModelStore.defaultBaseDirectory) {
        self.model = model
        self.baseDirectory = baseDirectory
    }

    /// Downloads `model` into `baseDirectory` (skipping what is already there); `progress` is 0...1.
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
    }

    /// Loads the downloaded model and returns how long that took. The first load on a machine makes
    /// Core ML compile the model for its chip, which takes about a minute; later loads take seconds.
    /// Never downloads the model (the tokenizer, a few MB, is fetched once if it is missing).
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
        guard let tokenizer = loaded.tokenizer else { throw TranscriberError.notLoaded }
        let tokens = Set(Language.allCases.compactMap { tokenizer.convertTokenToId("<|\($0.rawValue)|>") })
        guard tokens.count == Language.allCases.count else { throw TranscriberError.languageTokensMissing }
        loaded.tokenizer = RestrictedTokenizer(base: tokenizer, allLanguageTokens: tokens)
        kit = loaded
        return (ContinuousClock.now - start).seconds
    }

    /// Turns 16 kHz mono `samples` into text in `language`, or in the most probable of ru / en / ko
    /// when `language` is `nil`. Returns `nil` when there is nothing to transcribe: no speech in
    /// the recording, or the model heard none.
    public func transcribe(samples: [Float], language: Language?) async throws -> Transcript? {
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
        let start = ContinuousClock.now
        let options = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: chosen?.rawValue,
            usePrefillPrompt: true,
            detectLanguage: false,
            skipSpecialTokens: true,
            noSpeechThreshold: 0.6,
            chunkingStrategy: samples.count > Self.windowSamples ? .vad : nil
        )
        let results = try await kit.transcribe(audioArray: samples, decodeOptions: options)
        let text = results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let chosen else { return nil }
        return Transcript(
            text: text,
            language: chosen,
            languageProbability: probability,
            detectSeconds: detectSeconds,
            transcribeSeconds: (ContinuousClock.now - start).seconds
        )
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
