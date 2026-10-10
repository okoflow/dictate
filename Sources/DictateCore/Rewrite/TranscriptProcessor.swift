package struct TranscriptProcessor: Sendable {
    private let rewriters: PerProvider<any TextRewriter>

    package init(rewriters: PerProvider<any TextRewriter>) {
        self.rewriters = rewriters
    }

    package func process(
        _ transcript: String,
        language: Language,
        mode: Mode,
        cloud: CloudRewrite,
        vocabulary: Vocabulary,
    ) async -> ProcessedText {
        let corrected = vocabulary.correcting(transcript)

        if let snippet = vocabulary.snippet(matchingWhole: corrected) {
            return ProcessedText(text: snippet, requestedMode: mode, appliedMode: .raw, isSnippet: true)
        }

        let modeProcessor = ModeProcessor(rewriter: rewriters[cloud.provider])
        let processed = await modeProcessor.process(corrected, mode: mode, language: language, cloud: cloud)
        let finished = vocabulary.expandingSnippets(in: vocabulary.correcting(processed.text))

        return processed.replacingText(with: finished)
    }
}
