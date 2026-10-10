import DictateCore
import Foundation
import os

package struct AnthropicRewriter: TextRewriter {
    private let apiKeyStore: any ValueStore<String>
    private let session: URLSession

    package init(apiKeyStore: any ValueStore<String>, session: URLSession = URLSession(configuration: .ephemeral)) {
        self.apiKeyStore = apiKeyStore
        self.session = session
    }

    package func rewrite(_ text: String, mode: Mode, language: Language) async throws -> String {
        guard let apiKey = try? apiKeyStore.load(), !apiKey.isEmpty else { throw RewriteError.missingKey }
        guard let endpoint = URL(string: AnthropicMessagesCodec.endpoint) else { throw RewriteError.offline }

        var request = URLRequest(url: endpoint, timeoutInterval: ModeProcessor.cloudDeadline.timeInterval)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(AnthropicMessagesCodec.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try AnthropicMessagesCodec.requestBody(text: text, mode: mode, language: language)

        let (data, response) = try await send(request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw RewriteError.unreadableResponse }
        guard (200 ..< 300).contains(status) else {
            let detail = AnthropicMessagesCodec.errorDescription(from: data) ?? "no details"

            Logger.network.error("Claude answered HTTP \(status): \(detail, privacy: .public)")

            throw AnthropicMessagesCodec.error(forStatus: status)
        }

        return try AnthropicMessagesCodec.answer(from: data)
    }

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw RewriteError.timeout
        } catch {
            throw RewriteError.offline
        }
    }
}

extension Duration {
    fileprivate var timeInterval: TimeInterval {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
