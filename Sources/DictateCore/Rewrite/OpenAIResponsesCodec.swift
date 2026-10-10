import Foundation

package enum OpenAIResponsesCodec {
    package static let endpoint = "https://api.openai.com/v1/responses"
    package static let model = "gpt-6-luna"
    package static let reasoningEffort = "none"

    package static func requestBody(text: String, mode: Mode, language: Language) throws -> Data {
        let request = OpenAIResponsesRequest(
            model: model,
            instructions: RewritePrompt.system(for: mode),
            input: RewritePrompt.userMessage(text: text, language: language),
            maximumOutputTokens: maximumOutputTokens(for: text),
            reasoning: OpenAIResponsesRequest.Reasoning(effort: reasoningEffort),
            store: false,
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        return try encoder.encode(request)
    }

    package static func answer(from data: Data) throws -> String {
        guard let response = try? JSONDecoder().decode(OpenAIResponsesResponse.self, from: data) else {
            throw RewriteError.unreadableResponse
        }

        switch response.status {
        case "failed":
            throw RewriteError.serviceUnavailable(status: 200)
        case "incomplete":
            throw response.incompleteDetails?.reason == "content_filter" ? RewriteError.refused : RewriteError.truncated
        default:
            break
        }

        let content = response.output.filter { $0.type == "message" }.flatMap { $0.content ?? [] }
        guard !content.contains(where: { $0.type == "refusal" }) else { throw RewriteError.refused }

        let text = content.filter { $0.type == "output_text" }.compactMap(\.text).joined()

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    package static func errorDescription(from data: Data) -> String? {
        guard let response = try? JSONDecoder().decode(OpenAIResponsesError.self, from: data) else { return nil }

        let kind = response.error.code ?? response.error.type ?? "error"
        let message = response.error.message.replacingOccurrences(
            of: #"sk-[A-Za-z0-9*_\-]+"#,
            with: "sk-…",
            options: .regularExpression,
        )

        return "\(kind): \(message)"
    }

    package static func error(forStatus status: Int) -> RewriteError {
        switch status {
        case 401, 403: .rejectedKey
        case 429: .rateLimited
        default: .serviceUnavailable(status: status)
        }
    }

    private static func maximumOutputTokens(for text: String) -> Int {
        min(4096, max(512, text.count * 2))
    }
}
