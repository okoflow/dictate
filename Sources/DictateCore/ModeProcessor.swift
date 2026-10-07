import Foundation

/// Rewrites text with an LLM for a cloud mode. The app's implementation calls the Anthropic API; tests use fakes.
public protocol TextRewriter: Sendable {
    func rewrite(_ text: String, mode: Mode, language: Language) async throws -> String
}

/// Why a cloud mode fell back to Light. Shown on the pill and logged; never contains the text.
public enum FallbackReason: String, Codable, Equatable, Sendable {
    case noKey
    case badKey
    case offline
    case timeout
    case rateLimited
    case serviceError
    /// The answer was truncated, refused, unreadable, or failed `CloudAnswerCheck`.
    case unusableAnswer

    init(_ error: CloudError) {
        switch error {
        case .offline: self = .offline
        case .timeout: self = .timeout
        case .badKey: self = .badKey
        case .rateLimited: self = .rateLimited
        case .service: self = .serviceError
        case .unreadableAnswer, .truncated, .refused: self = .unusableAnswer
        }
    }

    /// For the pill: "Light: no API key".
    public var message: String {
        switch self {
        case .noKey: "Light: no API key (menu: Set Anthropic API key…)"
        case .badKey: "Light: the API key was rejected"
        case .offline: "Light: offline"
        case .timeout: "Light: no answer in 3 s"
        case .rateLimited: "Light: the API is rate-limiting"
        case .serviceError: "Light: the API returned an error"
        case .unusableAnswer: "Light: the answer was unusable"
        }
    }
}

/// The text after a mode was applied, and what really happened.
public struct ProcessedText: Equatable, Sendable {
    public let text: String
    public let requested: Mode
    /// `requested`, or `.light` after a fallback.
    public let applied: Mode
    public let fallback: FallbackReason?
    /// Whether a request was sent to the cloud (even one that then failed).
    public let contactedCloud: Bool

    public init(text: String, requested: Mode, applied: Mode, fallback: FallbackReason?, contactedCloud: Bool) {
        self.text = text
        self.requested = requested
        self.applied = applied
        self.fallback = fallback
        self.contactedCloud = contactedCloud
    }

    /// The same outcome with another text (the dictionary and snippets applied after the mode).
    public func with(text: String) -> ProcessedText {
        ProcessedText(text: text, requested: requested, applied: applied, fallback: fallback, contactedCloud: contactedCloud)
    }
}

/// Applies a mode. Raw and Light run here and never touch the rewriter; the cloud modes call it with a deadline
/// and fall back to Light on any problem, so a dictation never ends without text.
public struct ModeProcessor: Sendable {
    public static let cloudTimeout: Duration = .seconds(3)

    /// `nil` when there is no API key.
    private let rewriter: (any TextRewriter)?
    private let timeout: Duration

    public init(rewriter: (any TextRewriter)?, timeout: Duration = cloudTimeout) {
        self.rewriter = rewriter
        self.timeout = timeout
    }

    public func process(_ text: String, mode: Mode, language: Language) async -> ProcessedText {
        switch mode {
        case .raw:
            return ProcessedText(text: text, requested: mode, applied: .raw, fallback: nil, contactedCloud: false)
        case .light:
            return light(text, language: language, requested: mode, fallback: nil, contactedCloud: false)
        case .clean, .formal, .translate:
            guard let rewriter else {
                return light(text, language: language, requested: mode, fallback: .noKey, contactedCloud: false)
            }
            do {
                let answer = try await withDeadline { try await rewriter.rewrite(text, mode: mode, language: language) }
                guard let accepted = CloudAnswerCheck.accepted(answer, for: text, mode: mode, language: language) else {
                    return light(text, language: language, requested: mode, fallback: .unusableAnswer, contactedCloud: true)
                }
                return ProcessedText(text: accepted, requested: mode, applied: mode, fallback: nil, contactedCloud: true)
            } catch let error as CloudError {
                return light(text, language: language, requested: mode, fallback: FallbackReason(error), contactedCloud: true)
            } catch {
                return light(text, language: language, requested: mode, fallback: .offline, contactedCloud: true)
            }
        }
    }

    private func light(
        _ text: String, language: Language, requested: Mode, fallback: FallbackReason?, contactedCloud: Bool
    ) -> ProcessedText {
        ProcessedText(
            text: LightRules.apply(text, language: language),
            requested: requested,
            applied: .light,
            fallback: fallback,
            contactedCloud: contactedCloud
        )
    }

    /// Runs `body`, or throws `CloudError.timeout` when it takes longer than `timeout` (and cancels it).
    private func withDeadline(_ body: @escaping @Sendable () async throws -> String) async throws -> String {
        let timeout = timeout
        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { try await body() }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw CloudError.timeout
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw CloudError.timeout }
            return first
        }
    }
}

/// Whether an LLM answer can be pasted: not empty, not wildly longer than what was said, and in the right
/// script (the spoken language for Clean and Formal, English for Translate). Tags or quotes the model wrapped
/// the text in are taken off.
enum CloudAnswerCheck {
    static func accepted(_ answer: String, for input: String, mode: Mode, language: Language) -> String? {
        let text = unwrapped(answer, input: input)
        guard !text.isEmpty, text.count <= input.count * 3 + 60 else { return nil }
        let expected: Script = mode == .translate ? .latin : Script(language)
        // Only judge the script when the answer has one: digits or a name alone are fine.
        if let script = Script.dominant(in: text), script != expected {
            return nil
        }
        return text
    }

    /// Quotes are kept when the dictation itself started with one.
    private static func unwrapped(_ answer: String, input: String) -> String {
        var text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        for (open, close) in [("<transcript>", "</transcript>"), ("\"", "\""), ("«", "»")]
            where text.hasPrefix(open) && text.hasSuffix(close) && text.count > open.count + close.count
            && !input.hasPrefix(open) {
            text = String(text.dropFirst(open.count).dropLast(close.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }
}
