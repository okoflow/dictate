import Foundation

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
        case .missingKey: String(localized: "Used Light: add your \(name) API key in Settings › AI Models")

        case .unavailable: unavailableMessage(for: provider)

        case .rejectedKey: String(localized: "Used Light: \(name) rejected the API key")

        case .offline: offlineMessage(for: provider)

        case .timeout: String(localized: "Used Light: \(name) didn't answer in time")

        case .rateLimited: String(localized: "Used Light: \(name) is rate-limiting requests")

        case .serviceError: String(localized: "Used Light: \(name) returned an error")

        case .unusableAnswer: String(localized: "Used Light: \(name)'s answer couldn't be used")
        }
    }

    private func offlineMessage(for provider: ModelProvider) -> String {
        if provider == .localServer {
            return String(localized: "Used Light: the local server isn't running")
        }

        return String(localized: "Used Light: you're offline")
    }

    private func unavailableMessage(for provider: ModelProvider) -> String {
        switch provider {
        case .apple: String(localized: "Used Light: Apple Intelligence isn't available on this Mac")
        case .localServer: String(localized: "Used Light: choose a local server and model in Settings › AI Models")
        case let .cloud(provider): String(localized: "Used Light: \(provider.title) isn't available")
        }
    }
}
