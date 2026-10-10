package struct CloudRewrite: Sendable {
    package let provider: CloudProvider
    package let instructions: String

    package init(provider: CloudProvider, instructions: String) {
        self.provider = provider
        self.instructions = instructions
    }
}
