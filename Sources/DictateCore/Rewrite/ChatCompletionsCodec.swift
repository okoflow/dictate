import Foundation

package enum ChatCompletionsCodec {
    package static func endpoint(for server: LocalServer, path: String) -> String {
        var base = server.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)

        while base.hasSuffix("/") {
            base.removeLast()
        }

        return base + path
    }

    package static func requestBody(for rewrite: RewriteRequest, model: String) throws -> Data {
        let request = ChatCompletionsRequest(
            model: model,
            messages: [
                ChatCompletionsRequest.Message(role: "system", content: RewritePrompt.system(instructions: rewrite.instructions)),
                ChatCompletionsRequest.Message(role: "user", content: RewritePrompt.userMessage(for: rewrite)),
            ],
            temperature: 0.2,
            maximumTokens: min(4096, max(512, rewrite.text.count * 2)),
            stream: false,
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        return try encoder.encode(request)
    }

    package static func answer(from data: Data) throws -> String {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let response = try? decoder.decode(ChatCompletionsResponse.self, from: data),
              let choice = response.choices.first else { throw RewriteError.unreadableResponse }

        switch choice.finishReason {
        case "length": throw RewriteError.truncated
        case "content_filter": throw RewriteError.refused
        default: break
        }

        let content = (choice.message.content ?? "")
            .replacingOccurrences(of: #"<think>[\s\S]*?</think>"#, with: "", options: .regularExpression)

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    package static func models(from data: Data) -> [String]? {
        (try? JSONDecoder().decode(ChatCompletionsResponse.ModelList.self, from: data))?.data.map(\.id)
    }

    package static func error(forStatus status: Int) -> RewriteError {
        switch status {
        case 401, 403: .rejectedKey
        case 404: .unavailable
        case 429: .rateLimited
        default: .serviceUnavailable(status: status)
        }
    }
}
