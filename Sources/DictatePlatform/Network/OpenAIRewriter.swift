import DictateCore
import Foundation
import os

package struct OpenAIRewriter: TextRewriter {
    private let apiKeyStore: any ValueStore<String>
    private let transport: RewriteTransport

    package init(apiKeyStore: any ValueStore<String>, session: URLSession = URLSession(configuration: .ephemeral)) {
        self.apiKeyStore = apiKeyStore
        transport = RewriteTransport(session: session)
    }

    package func rewrite(_ request: RewriteRequest) async throws -> String {
        guard let apiKey = try? apiKeyStore.load(), !apiKey.isEmpty else { throw RewriteError.missingKey }

        let body = try OpenAIResponsesCodec.requestBody(for: request)
        let headers = [
            "authorization": "Bearer \(apiKey)",
            "content-type": "application/json",
        ]

        let (data, status) = try await transport.post(body, to: OpenAIResponsesCodec.endpoint, headers: headers)
        guard (200 ..< 300).contains(status) else {
            let detail = OpenAIResponsesCodec.errorDescription(from: data) ?? "no details"

            Logger.network.error("OpenAI answered HTTP \(status): \(detail, privacy: .public)")

            throw OpenAIResponsesCodec.error(forStatus: status)
        }

        return try OpenAIResponsesCodec.answer(from: data)
    }
}
