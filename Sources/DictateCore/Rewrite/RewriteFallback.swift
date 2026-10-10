package enum RewriteFallback: String, Sendable {
    case missingKey
    case unavailable
    case rejectedKey
    case offline
    case timeout
    case rateLimited
    case serviceError
    case unusableAnswer

    package init(_ error: RewriteError) {
        switch error {
        case .missingKey: self = .missingKey
        case .unavailable: self = .unavailable
        case .rejectedKey: self = .rejectedKey
        case .offline: self = .offline
        case .timeout: self = .timeout
        case .rateLimited: self = .rateLimited
        case .serviceUnavailable: self = .serviceError
        case .unreadableResponse, .truncated, .refused: self = .unusableAnswer
        }
    }

    package func message(for provider: ModelProvider) -> String {
        let name = provider.title

        return switch self {
        case .missingKey: "Used Light: add your \(name) API key in Settings › AI Models"
        case .unavailable: unavailableMessage(for: provider)
        case .rejectedKey: "Used Light: \(name) rejected the API key"
        case .offline: provider == .localServer ? "Used Light: the local server isn't running" : "Used Light: you're offline"
        case .timeout: "Used Light: \(name) didn't answer in time"
        case .rateLimited: "Used Light: \(name) is rate-limiting requests"
        case .serviceError: "Used Light: \(name) returned an error"
        case .unusableAnswer: "Used Light: \(name)'s answer couldn't be used"
        }
    }

    private func unavailableMessage(for provider: ModelProvider) -> String {
        switch provider {
        case .apple: "Used Light: Apple Intelligence isn't available on this Mac"
        case .localServer: "Used Light: choose a local server and model in Settings › AI Models"
        case let .cloud(provider): "Used Light: \(provider.title) isn't available"
        }
    }
}
