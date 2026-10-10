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
        String(localized: "Used Light: \(reason(for: provider))")
    }

    package func reason(for provider: ModelProvider) -> String {
        let name = provider.title

        return switch self {
        case .missingKey: String(localized: "add your \(name) API key in Settings › AI Models")
        case .unavailable: unavailableReason(for: provider)
        case .rejectedKey: String(localized: "\(name) rejected the API key")
        case .offline: offlineReason(for: provider)
        case .timeout: String(localized: "\(name) didn't answer in time")
        case .rateLimited: String(localized: "\(name) is rate-limiting requests")
        case .serviceError: String(localized: "\(name) returned an error")
        case .unusableAnswer: String(localized: "\(name)'s answer couldn't be used")
        }
    }

    private func offlineReason(for provider: ModelProvider) -> String {
        if provider == .localServer {
            return String(localized: "the local server isn't running")
        }

        return String(localized: "you're offline")
    }

    private func unavailableReason(for provider: ModelProvider) -> String {
        switch provider {
        case .apple: String(localized: "Apple Intelligence isn't available on this Mac")
        case .localServer: String(localized: "choose a local server and model in Settings › AI Models")
        case let .cloud(provider): String(localized: "\(provider.title) isn't available")
        }
    }
}
