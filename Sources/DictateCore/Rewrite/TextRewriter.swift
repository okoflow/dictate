package protocol TextRewriter: Sendable {
    func rewrite(_ text: String, instructions: String, language: Language) async throws -> String
}
