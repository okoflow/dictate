import DictateCore
import Foundation

struct RewriteTransport: Sendable {
    private let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    func post(
        _ body: Data,
        to endpoint: String,
        headers: [String: String],
        timeout: Duration = ModeProcessor.cloudDeadline,
    ) async throws -> (data: Data, status: Int) {
        guard let url = URL(string: endpoint) else { throw RewriteError.offline }

        var request = URLRequest(url: url, timeoutInterval: timeout.timeInterval)
        request.httpMethod = "POST"
        request.httpBody = body

        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        let (data, response) = try await send(request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw RewriteError.unreadableResponse }

        return (data, status)
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
