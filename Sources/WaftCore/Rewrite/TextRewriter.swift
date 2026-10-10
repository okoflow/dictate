package protocol TextRewriter: Sendable {
    func rewrite(_ request: RewriteRequest) async throws -> String
}
