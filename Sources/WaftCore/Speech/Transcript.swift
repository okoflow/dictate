package struct Transcript: Equatable, Sendable {
    package let text: String
    package let language: Language
    package let detectionDuration: Duration
    package let decodingDuration: Duration

    package init(text: String, language: Language, detectionDuration: Duration, decodingDuration: Duration) {
        self.text = text
        self.language = language
        self.detectionDuration = detectionDuration
        self.decodingDuration = decodingDuration
    }
}
