import Foundation
import os
import WaftCore

package struct LocalServerRewriter: TextRewriter, LocalServerBrowsing {
    private static let listTimeout: TimeInterval = 1.5

    private let session: URLSession
    private let transport: RewriteTransport

    package init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
        transport = RewriteTransport(session: session)
    }

    package func rewrite(_ request: RewriteRequest) async throws -> String {
        guard let server = request.localServer, server.isConfigured else { throw RewriteError.unavailable }

        let body = try ChatCompletionsCodec.requestBody(for: request, model: server.model)
        let (data, status) = try await transport.post(
            body,
            to: ChatCompletionsCodec.endpoint(for: server, path: "/chat/completions"),
            headers: ["content-type": "application/json"],
            timeout: ModelProvider.localServer.deadline,
        )
        guard (200 ..< 300).contains(status) else {
            Logger.network.error("The local server answered HTTP \(status)")

            throw ChatCompletionsCodec.error(forStatus: status)
        }

        return try ChatCompletionsCodec.answer(from: data)
    }

    package func models(at server: LocalServer) async -> [String]? {
        guard let url = URL(string: ChatCompletionsCodec.endpoint(for: server, path: "/models")) else { return nil }

        let request = URLRequest(url: url, timeoutInterval: Self.listTimeout)
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

        return ChatCompletionsCodec.models(from: data)
    }
}
