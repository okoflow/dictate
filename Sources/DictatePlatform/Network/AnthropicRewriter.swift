import DictateCore
import Foundation
import os

package struct AnthropicRewriter: TextRewriter {
    private let apiKeyStore: any ValueStore<String>
    private let transport: RewriteTransport

    package init(apiKeyStore: any ValueStore<String>, session: URLSession = URLSession(configuration: .ephemeral)) {
        self.apiKeyStore = apiKeyStore
        transport = RewriteTransport(session: session)
    }

    package func rewrite(_ text: String, instructions: String, language: Language) async throws -> String {
        guard let apiKey = try? apiKeyStore.load(), !apiKey.isEmpty else { throw RewriteError.missingKey }

        let body = try AnthropicMessagesCodec.requestBody(text: text, instructions: instructions, language: language)
        let headers = [
            "x-api-key": apiKey,
            "anthropic-version": AnthropicMessagesCodec.apiVersion,
            "content-type": "application/json",
        ]

        let (data, status) = try await transport.post(body, to: AnthropicMessagesCodec.endpoint, headers: headers)
        guard (200 ..< 300).contains(status) else {
            let detail = AnthropicMessagesCodec.errorDescription(from: data) ?? "no details"

            Logger.network.error("Claude answered HTTP \(status): \(detail, privacy: .public)")

            throw AnthropicMessagesCodec.error(forStatus: status)
        }

        return try AnthropicMessagesCodec.answer(from: data)
    }
}
