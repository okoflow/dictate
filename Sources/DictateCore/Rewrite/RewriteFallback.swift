package enum RewriteFallback: String, Sendable {
    case missingKey
    case rejectedKey
    case offline
    case timeout
    case rateLimited
    case serviceError
    case unusableAnswer

    package init(_ error: RewriteError) {
        switch error {
        case .missingKey: self = .missingKey
        case .rejectedKey: self = .rejectedKey
        case .offline: self = .offline
        case .timeout: self = .timeout
        case .rateLimited: self = .rateLimited
        case .serviceUnavailable: self = .serviceError
        case .unreadableResponse, .truncated, .refused: self = .unusableAnswer
        }
    }

    package func message(for provider: CloudProvider) -> String {
        let name = provider.title

        return switch self {
        case .missingKey: "Used Light: add your \(name) API key in Settings › AI Models"
        case .rejectedKey: "Used Light: \(name) rejected the API key"
        case .offline: "Used Light: you're offline"
        case .timeout: "Used Light: \(name) didn't answer within 3 seconds"
        case .rateLimited: "Used Light: \(name) is rate-limiting requests"
        case .serviceError: "Used Light: \(name) returned an error"
        case .unusableAnswer: "Used Light: \(name)'s answer couldn't be used"
        }
    }
}
