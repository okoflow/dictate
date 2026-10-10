package protocol TextRewriter: Sendable {
    func rewrite(_ text: String, mode: Mode, language: Language) async throws -> String
}
