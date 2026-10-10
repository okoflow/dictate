package struct ModeProcessor: Sendable {
    package static let cloudDeadline = Duration.seconds(3)

    private let rewriter: any TextRewriter
    private let deadline: Duration
    private let contactsCloud: Bool

    package init(rewriter: any TextRewriter, deadline: Duration = cloudDeadline, contactsCloud: Bool = true) {
        self.rewriter = rewriter
        self.deadline = deadline
        self.contactsCloud = contactsCloud
    }

    package func process(_ text: String, mode: Mode, language: Language, setup: RewriteSetup) async -> ProcessedText {
        switch mode {
        case .raw:
            ProcessedText(text: text, requestedMode: mode, appliedMode: .raw)
        case .light:
            light(text, language: language, requestedMode: mode)
        case .clean, .formal, .translate:
            await rewrite(RewriteRequest(
                text: text,
                instructions: setup.instructions,
                language: language,
                target: mode == .translate ? setup.translation.target(forSpoken: language) : nil,
                localServer: setup.provider == .localServer ? setup.localServer : nil,
            ), mode: mode)
        }
    }

    package func light(
        _ text: String,
        language: Language,
        requestedMode: Mode,
        fallback: RewriteFallback? = nil,
        contactedCloud: Bool = false,
    ) -> ProcessedText {
        ProcessedText(
            text: VoiceCommands.apply(LightModeRules.apply(text, language: language), language: language),
            requestedMode: requestedMode,
            appliedMode: .light,
            fallback: fallback,
            contactedCloud: contactedCloud,
        )
    }

    private func rewrite(_ request: RewriteRequest, mode: Mode) async -> ProcessedText {
        let text = request.text
        let language = request.language

        do {
            let answer = try await RewriteDeadline.run(deadline) { [rewriter] in
                try await rewriter.rewrite(request)
            }
            guard let accepted = RewriteValidator.validated(answer, for: request, mode: mode) else {
                return light(
                    text,
                    language: language,
                    requestedMode: mode,
                    fallback: .unusableAnswer,
                    contactedCloud: contactsCloud,
                )
            }

            return ProcessedText(text: accepted, requestedMode: mode, appliedMode: mode, contactedCloud: contactsCloud)
        } catch {
            let rewriteError = error as? RewriteError ?? .offline
            let fallback = RewriteFallback(rewriteError)

            return light(
                text,
                language: language,
                requestedMode: mode,
                fallback: fallback,
                contactedCloud: contactsCloud && rewriteError != .missingKey,
            )
        }
    }
}
