package struct ProcessedText: Equatable, Sendable {
    package let text: String
    package let requestedMode: Mode
    package let appliedMode: Mode
    package let fallback: RewriteFallback?
    package let contactedCloud: Bool
    package let isSnippet: Bool

    package init(
        text: String,
        requestedMode: Mode,
        appliedMode: Mode,
        fallback: RewriteFallback? = nil,
        contactedCloud: Bool = false,
        isSnippet: Bool = false,
    ) {
        self.text = text
        self.requestedMode = requestedMode
        self.appliedMode = appliedMode
        self.fallback = fallback
        self.contactedCloud = contactedCloud
        self.isSnippet = isSnippet
    }

    package func replacingText(with text: String) -> ProcessedText {
        ProcessedText(
            text: text,
            requestedMode: requestedMode,
            appliedMode: appliedMode,
            fallback: fallback,
            contactedCloud: contactedCloud,
            isSnippet: isSnippet,
        )
    }
}
