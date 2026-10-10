import Foundation

package enum AnthropicMessagesCodec {
    package static let endpoint = "https://api.anthropic.com/v1/messages"
    package static let apiVersion = "2023-06-01"
    package static let model = "claude-haiku-5-5"

    package static func requestBody(text: String, mode: Mode, language: Language) throws -> Data {
        let message = MessagesRequest.Message(role: "user", content: RewritePrompt.userMessage(text: text, language: language))
        let request = MessagesRequest(
            model: model,
            maximumTokens: maximumTokens(for: text),
            thinking: MessagesRequest.Thinking(type: "disabled"),
            system: RewritePrompt.system(for: mode),
            messages: [message],
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        return try encoder.encode(request)
    }

    package static func answer(from data: Data) throws -> String {
        guard let response = try? JSONDecoder().decode(MessagesResponse.self, from: data) else {
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
