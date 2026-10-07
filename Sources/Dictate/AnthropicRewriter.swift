import DictateCore
import Foundation

/// Rewrites text for Clean, Formal and Translate with Claude Haiku through the Anthropic Messages API.
/// `ModeProcessor` enforces the 3 s deadline; the request's own timeout is the same, as a backstop.
struct AnthropicRewriter: TextRewriter {
    /// No cache, no cookies, nothing kept on disk.
    private static let session = URLSession(configuration: .ephemeral)

    let apiKey: String
    let endpoint: URL

    func rewrite(_ text: String, mode: Mode, language: Language) async throws -> String {
        var request = URLRequest(url: endpoint, timeoutInterval: 3)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(CloudPrompt.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try CloudPrompt.requestBody(text: text, mode: mode, language: language)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await Self.session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw CloudError.timeout
        } catch {
            throw CloudError.offline
        }
        guard let http = response as? HTTPURLResponse else { throw CloudError.unreadableAnswer }
        guard (200 ..< 300).contains(http.statusCode) else { throw CloudPrompt.error(forStatus: http.statusCode) }
        return try CloudPrompt.answer(from: data)
    }

    /// The rewriter for this moment: the Keychain key and the API, or (E2E only) the suite's local proxy with a
    /// placeholder key, so the real key never goes to another address. `nil` = no key: cloud modes use Light.
    static func current(options: LaunchOptions) -> AnthropicRewriter? {
        if let endpoint = options.llmEndpoint.flatMap(URL.init(string:)) {
            return AnthropicRewriter(apiKey: "e2e", endpoint: endpoint)
        }
        guard let key = APIKeyStore.read(), let endpoint = URL(string: CloudPrompt.endpoint) else { return nil }
        return AnthropicRewriter(apiKey: key, endpoint: endpoint)
    }
}
