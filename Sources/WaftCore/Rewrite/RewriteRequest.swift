package struct RewriteRequest: Sendable {
    package let text: String
    package let instructions: String
    package let language: Language
    package let target: Language?
    package let localServer: LocalServer?
    package let selection: String?

    package var outputTokenBudget: Int {
        min(4096, max(selection == nil ? 512 : 1024, (selection ?? text).count * 2))
    }

    package init(
        text: String,
        instructions: String,
        language: Language,
        target: Language? = nil,
        localServer: LocalServer? = nil,
        selection: String? = nil,
    ) {
        self.text = text
        self.instructions = instructions
        self.language = language
        self.target = target
        self.localServer = localServer
        self.selection = selection
    }
}
