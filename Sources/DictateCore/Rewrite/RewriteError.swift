package enum RewriteError: Error, Equatable, Sendable {
    case missingKey
    case offline
    case timeout
    case rejectedKey
    case rateLimited
    case serviceUnavailable(status: Int)
    case unreadableResponse
    case truncated
    case refused
}
