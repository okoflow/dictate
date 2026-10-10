import Foundation

package enum AnthropicMessagesCodec {
    package static let endpoint = "https://api.anthropic.com/v1/messages"
    package static let apiVersion = "2023-06-01"
    package static let model = "claude-haiku-5-5"

    package static func requestBody(for rewrite: RewriteRequest) throws -> Data {
        let message = AnthropicMessagesRequest.Message(
            role: "user",
            content: RewritePrompt.userMessage(for: rewrite),
        )
        let request = AnthropicMessagesRequest(
            model: model,
            maximumTokens: maximumTokens(for: rewrite.text),
            thinking: AnthropicMessagesRequest.Thinking(type: "disabled"),
            system: RewritePrompt.system(instructions: rewrite.instructions),
            messages: [message],
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        return try encoder.encode(request)
    }

    package static func answer(from data: Data) throws -> String {
        guard let response = try? JSONDecoder().decode(AnthropicMessagesResponse.self, from: data) else {
            throw RewriteError.unreadableResponse
        }

        switch response.stopReason {
        case "max_tokens": throw RewriteError.truncated
        case "refusal": throw RewriteError.refused
        default: break
        }

        let text = response.content.filter { $0.type == "text" }.compactMap(\.text).joined()

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    package static func errorDescription(from data: Data) -> String? {
        guard let response = try? JSONDecoder().decode(AnthropicMessagesError.self, from: data) else { return nil }

        return "\(response.error.type): \(response.error.message)"
    }

    package static func error(forStatus status: Int) -> RewriteError {
        switch status {
        case 401, 403: .rejectedKey
        case 429: .rateLimited
        default: .serviceUnavailable(status: status)
        }
    }

    private static func maximumTokens(for text: String) -> Int {
        min(4096, max(256, text.count * 2))
    }
}
