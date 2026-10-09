import CryptoKit
import DictateCore
import Foundation
import Network

/// A local stand-in for the Anthropic Messages API. Dictate is launched with `--llm-endpoint` pointing here, so
/// the suite decides what the "LLM" answers and sees every request the app sends:
///
/// - `replay`: the answer recorded for the same request body (`e2e/cassettes/llm.json`), delayed by the latency
///   measured when it was recorded. A request with no recording gets a 500 and is counted as a miss.
/// - `record`: forwards to the real API with the real key (the app only ever sends the placeholder `e2e`), and
///   records the answer and its latency.
/// - `stub`, `delay`, `drop`: a fixed answer (`[stub] ` + the transcript), the same after a wait, or a dropped
///   connection, for the plumbing and fallback checks; they need no key.
///
/// It listens on the loopback interface only. The state is shared between the listener's queue and the main
/// thread, so every access goes through `lock` (hence `@unchecked Sendable`).
final class LLMProxy: @unchecked Sendable {
    enum Behaviour {
        case replay
        case record(apiKey: String)
        case stub
        case delay(TimeInterval)
        case drop
    }

    struct Received {
        let headers: [String: String]
        let body: Data
    }

    static let stubPrefix = "[stub] "

    private let lock = NSLock()
    private var currentBehaviour = Behaviour.stub
    private var requests: [Received] = []
    private var missed: [String] = []
    private var cassette: Cassette
    private let cassetteURL: URL
    private let listener: NWListener
    private let queue = DispatchQueue(label: "dev.dictate.e2e.llm-proxy")
    private(set) var port: UInt16 = 0

    var endpoint: String {
        "http://127.0.0.1:\(port)/v1/messages"
    }

    var behaviour: Behaviour {
        get { lock.withLock { currentBehaviour } }
        set { lock.withLock { currentBehaviour = newValue } }
    }

    var received: [Received] {
        lock.withLock { requests }
    }

    /// Why replay had no answer for the transcripts it missed: none recorded for that text, or one recorded with
    /// another prompt or model (the request changed since the recording).
    var misses: [String] {
        lock.withLock { missed }
    }

    var recordedAnswers: Int {
        lock.withLock { cassette.entries.count }
    }

    init(cassetteURL: URL) throws {
        self.cassetteURL = cassetteURL
        cassette = (try? JSONDecoder().decode(Cassette.self, from: Data(contentsOf: cassetteURL))) ?? Cassette(entries: [:])
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        listener = try NWListener(using: parameters)
        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in
            if case .ready = state {
                ready.signal()
            }
        }
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        listener.start(queue: queue)
        guard ready.wait(timeout: .now() + 5) == .success, let port = listener.port?.rawValue else {
            throw Verdict.fail("the local LLM proxy did not start")
        }
        self.port = port
    }

    func stop() {
        listener.cancel()
    }

    // MARK: Connections

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            buffer.append(data ?? Data())
            if let request = HTTPRequest(parsing: buffer) {
                handle(request, on: connection)
            } else if isComplete || error != nil {
                connection.cancel()
            } else {
                receive(on: connection, buffer: buffer)
            }
        }
    }

    private func handle(_ request: HTTPRequest, on connection: NWConnection) {
        let behaviour = lock.withLock {
            requests.append(Received(headers: request.headers, body: request.body))
            return currentBehaviour
        }
        switch behaviour {
        case .stub:
            respond(on: connection, status: 200, body: Self.stubAnswer(for: request.body))
        case let .delay(seconds):
            queue.asyncAfter(deadline: .now() + seconds) {
                self.respond(on: connection, status: 200, body: Self.stubAnswer(for: request.body))
            }
        case .drop:
            connection.cancel()
        case .replay:
            replay(request, on: connection)
        case let .record(apiKey):
            forward(request, apiKey: apiKey, on: connection)
        }
    }

    private func replay(_ request: HTTPRequest, on connection: NWConnection) {
        let key = Self.key(for: request.body)
        guard let entry = lock.withLock({ cassette.entries[key] }) else {
            let transcript = Self.transcript(in: request.body) ?? ""
            lock.withLock {
                let changed = cassette.entries.values.contains { $0.transcript == transcript }
                missed.append("\"\(transcript)\": " + (changed ? "recorded with another prompt or model" : "never recorded"))
            }
            respond(on: connection, status: 500, body: Data(#"{"error":"no recorded answer for this request"}"#.utf8))
            return
        }
        queue.asyncAfter(deadline: .now() + entry.seconds) {
            self.respond(on: connection, status: entry.status, body: Data(entry.response.utf8))
        }
    }

    private func forward(_ request: HTTPRequest, apiKey: String, on connection: NWConnection) {
        guard let url = URL(string: CloudPrompt.endpoint) else { return }
        var upstream = URLRequest(url: url, timeoutInterval: 30)
        upstream.httpMethod = "POST"
        upstream.httpBody = request.body
        upstream.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        upstream.setValue(request.headers["anthropic-version"] ?? CloudPrompt.apiVersion, forHTTPHeaderField: "anthropic-version")
        upstream.setValue("application/json", forHTTPHeaderField: "content-type")
        let start = Date()
        URLSession.shared.dataTask(with: upstream) { [weak self] data, response, _ in
            guard let self else { return }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 502
            let body = data ?? Data()
            if status == 200 {
                record(Cassette.Entry(
                    transcript: Self.transcript(in: request.body) ?? "",
                    status: status,
                    seconds: Date().timeIntervalSince(start),
                    response: String(bytes: body, encoding: .utf8) ?? ""
                ), for: request.body)
            }
            respond(on: connection, status: status, body: body)
        }.resume()
    }

    private func record(_ entry: Cassette.Entry, for body: Data) {
        let snapshot = lock.withLock {
            cassette.entries[Self.key(for: body)] = entry
            return cassette
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try? FileManager.default.createDirectory(at: cassetteURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? encoder.encode(snapshot).write(to: cassetteURL, options: .atomic)
    }

    private func respond(on connection: NWConnection, status: Int, body: Data) {
        let head = "HTTP/1.1 \(status) \(status == 200 ? "OK" : "Error")\r\n"
            + "Content-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
    }

    // MARK: Bodies

    /// The cassette key: a hash of the whole request body, so a changed prompt, model or transcript is a miss.
    static func key(for body: Data) -> String {
        SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
    }

    /// The transcript the app put between `<transcript>` tags.
    static func transcript(in body: Data) -> String? {
        guard let request = try? JSONDecoder().decode(SentRequest.self, from: body),
              let content = request.messages.first?.content,
              let start = content.range(of: "<transcript>\n"),
              let end = content.range(of: "\n</transcript>", options: .backwards),
              start.upperBound <= end.lowerBound
        else { return nil }
        return String(content[start.upperBound ..< end.lowerBound])
    }

    private static func stubAnswer(for body: Data) -> Data {
        let text = stubPrefix + (transcript(in: body) ?? "")
        let answer: [String: Any] = [
            "type": "message", "role": "assistant", "model": CloudPrompt.model,
            "content": [["type": "text", "text": text]], "stop_reason": "end_turn",
        ]
        return (try? JSONSerialization.data(withJSONObject: answer)) ?? Data()
    }
}

/// The request body as the app sends it (the fields the checks look at).
struct SentRequest: Decodable {
    struct Message: Decodable {
        let role: String
        let content: String
    }

    struct Thinking: Decodable {
        let type: String
    }

    let model: String
    let thinking: Thinking?
    let system: String
    let messages: [Message]
}

/// Recorded answers, keyed by `LLMProxy.key(for:)`.
struct Cassette: Codable {
    struct Entry: Codable {
        /// For a person reading the file; the key is what matches.
        let transcript: String
        let status: Int
        let seconds: Double
        let response: String
    }

    var entries: [String: Entry]
}

/// Just enough HTTP/1.1 to read one request: headers (lowercased names) and a `Content-Length` body.
private struct HTTPRequest {
    let headers: [String: String]
    let body: Data

    /// `nil` until `data` holds the whole request.
    init?(parsing data: Data) {
        guard let end = data.range(of: Data("\r\n\r\n".utf8)),
              let head = String(bytes: data[..<end.lowerBound], encoding: .utf8)
        else { return nil }
        var headers: [String: String] = [:]
        for line in head.components(separatedBy: "\r\n").dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].lowercased()
            headers[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        let length = headers["content-length"].flatMap(Int.init) ?? 0
        let body = data[end.upperBound...]
        guard body.count >= length else { return nil }
        self.headers = headers
        self.body = Data(body.prefix(length))
    }
}
