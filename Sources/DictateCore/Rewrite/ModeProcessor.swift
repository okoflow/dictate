package struct ModeProcessor: Sendable {
    package static let cloudDeadline = Duration.seconds(3)

    private let rewriter: any TextRewriter
    private let deadline: Duration

    package init(rewriter: any TextRewriter, deadline: Duration = cloudDeadline) {
        self.rewriter = rewriter
        self.deadline = deadline
    }

    package func process(_ text: String, mode: Mode, language: Language) async -> ProcessedText {
        switch mode {
        case .raw:
            ProcessedText(text: text, requestedMode: mode, appliedMode: .raw)
        case .light:
            light(text, language: language, requestedMode: mode)
        case .clean, .formal, .translate:
            await rewrite(text, mode: mode, language: language)
        }
    }

    private func rewrite(_ text: String, mode: Mode, language: Language) async -> ProcessedText {
        do {
            let answer = try await withDeadline { try await rewriter.rewrite(text, mode: mode, language: language) }
            guard let accepted = RewriteValidator.validated(answer, for: text, mode: mode, language: language) else {
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
