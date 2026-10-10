package struct CloudRewrite: Sendable {
    package let provider: CloudProvider
    package let instructions: String
    package let translation: Translation

    package init(provider: CloudProvider, instructions: String, translation: Translation = Translation()) {
        self.provider = provider
        self.instructions = instructions
        self.translation = translation
    }
}
