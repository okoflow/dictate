package struct TranscriptProcessor: Sendable {
    private let rewriters: Rewriters

    package init(rewriters: Rewriters) {
        self.rewriters = rewriters
    }

    package func process(
        _ transcript: String,
        language: Language,
        mode: Mode,
        setup: RewriteSetup,
        vocabulary: Vocabulary,
    ) async -> ProcessedText {
        let corrected = vocabulary.correcting(transcript)

        if let snippet = vocabulary.snippet(matchingWhole: corrected) {
            return ProcessedText(text: snippet, requestedMode: mode, appliedMode: .raw, isSnippet: true)
        }

        let modeProcessor = ModeProcessor(
            rewriter: rewriters[setup.provider],
            deadline: setup.provider.deadline,
            contactsCloud: setup.provider.isCloud,
        )
        let processed = await modeProcessor.process(corrected, mode: mode, language: language, setup: setup)
        let finished = vocabulary.expandingSnippets(in: vocabulary.correcting(processed.text))

        return processed.replacingText(with: finished)
    }

    package func edit(_ selection: String, instruction: String, language: Language, setup: RewriteSetup) async throws -> String {
        let request = RewriteRequest(
            text: instruction,
            instructions: "",
            language: language,
            localServer: setup.provider == .localServer ? setup.localServer : nil,
            selection: selection,
        )
        let rewriter = rewriters[setup.provider]
        let answer = try await RewriteDeadline.run(setup.provider.editDeadline) {
            try await rewriter.rewrite(request)
        }
        guard let edited = RewriteValidator.validatedEdit(answer, of: selection) else { throw RewriteError.unreadableResponse }

        return edited
    }
}
