package enum RewriteError: Error, Equatable, Sendable {
    case missingKey
    case unavailable
    case offline
    case timeout
    case rejectedKey
    case rateLimited
    case serviceUnavailable(status: Int)
    case unreadableResponse
    case truncated
    case refused
}
