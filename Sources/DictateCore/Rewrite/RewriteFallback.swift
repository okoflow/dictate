package enum RewriteFallback: String, Sendable {
    case missingKey
    case rejectedKey
    case offline
    case timeout
    case rateLimited
    case serviceError
    case unusableAnswer

    package var message: String {
        switch self {
        case .missingKey: "Used Light: add a Claude API key in Settings › Modes"
        case .rejectedKey: "Used Light: Claude rejected the API key"
        case .offline: "Used Light: you're offline"
        case .timeout: "Used Light: Claude didn't answer within 3 seconds"
        case .rateLimited: "Used Light: Claude is rate-limiting requests"
        case .serviceError: "Used Light: Claude returned an error"
        case .unusableAnswer: "Used Light: Claude's answer couldn't be used"
        }
    }

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
}
