package struct RewriteRequest: Sendable {
    package let text: String
    package let instructions: String
    package let language: Language
    package let target: Language?
    package let localServer: LocalServer?

    package init(
        text: String,
        instructions: String,
        language: Language,
        target: Language? = nil,
        localServer: LocalServer? = nil,
    ) {
        self.text = text
        self.instructions = instructions
        self.language = language
        self.target = target
        self.localServer = localServer
    }
}
