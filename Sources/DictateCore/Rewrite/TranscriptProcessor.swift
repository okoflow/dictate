package struct TranscriptProcessor: Sendable {
    private let modeProcessor: ModeProcessor

    package init(rewriter: any TextRewriter) {
        modeProcessor = ModeProcessor(rewriter: rewriter)
    }

    package func process(_ transcript: String, language: Language, mode: Mode, vocabulary: Vocabulary) async -> ProcessedText {
        let corrected = vocabulary.correcting(transcript)

        if let snippet = vocabulary.snippet(matchingWhole: corrected) {
            return ProcessedText(text: snippet, requestedMode: mode, appliedMode: .raw, isSnippet: true)
        }

        let processed = await modeProcessor.process(corrected, mode: mode, language: language)
        let finished = vocabulary.expandingSnippets(in: vocabulary.correcting(processed.text))

        return processed.replacingText(with: finished)
    }
}
