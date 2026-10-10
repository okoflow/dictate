package struct ModeProcessor: Sendable {
    package static let cloudDeadline = Duration.seconds(3)

    private let rewriter: any TextRewriter
    private let deadline: Duration

    package init(rewriter: any TextRewriter, deadline: Duration = cloudDeadline) {
        self.rewriter = rewriter
        self.deadline = deadline
    }

    package func process(_ text: String, mode: Mode, language: Language, cloud: CloudRewrite) async -> ProcessedText {
        switch mode {
        case .raw:
            ProcessedText(text: text, requestedMode: mode, appliedMode: .raw)
        case .light:
            light(text, language: language, requestedMode: mode)
        case .clean, .formal, .translate:
            await rewrite(RewriteRequest(
                text: text,
                instructions: cloud.instructions,
                language: language,
                target: mode == .translate ? cloud.translation.target(forSpoken: language) : nil,
            ), mode: mode)
        }
    }

    private func rewrite(_ request: RewriteRequest, mode: Mode) async -> ProcessedText {
        let text = request.text
        let language = request.language

        do {
            let answer = try await withDeadline { [rewriter] in
                try await rewriter.rewrite(request)
            }
            guard let accepted = RewriteValidator.validated(answer, for: request, mode: mode) else {
                return light(text, language: language, requestedMode: mode, fallback: .unusableAnswer, contactedCloud: true)
            }

            return ProcessedText(text: accepted, requestedMode: mode, appliedMode: mode, contactedCloud: true)
        } catch {
            let rewriteError = error as? RewriteError ?? .offline
            let fallback = RewriteFallback(rewriteError)

            return light(
                text,
                language: language,
                requestedMode: mode,
                fallback: fallback,
                contactedCloud: rewriteError != .missingKey,
            )
        }
    }

    private func light(
        _ text: String,
        language: Language,
        requestedMode: Mode,
        fallback: RewriteFallback? = nil,
        contactedCloud: Bool = false,
    ) -> ProcessedText {
        ProcessedText(
            text: LightModeRules.apply(text, language: language),
            requestedMode: requestedMode,
            appliedMode: .light,
            fallback: fallback,
            contactedCloud: contactedCloud,
        )
    }

    private func withDeadline(_ operation: @escaping @Sendable () async throws -> String) async throws -> String {
        let deadline = deadline

        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: deadline)

                throw RewriteError.timeout
            }

            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw RewriteError.timeout }

            return first
        }
    }
}
