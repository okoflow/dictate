package struct LocalServer: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case baseURL
        case model
    }

    package static let knownServers: [(name: String, baseURL: String)] = [
        ("Ollama", "http://localhost:11434/v1"),
        ("LM Studio", "http://localhost:1234/v1"),
        ("llama.cpp or MLX", "http://localhost:8080/v1"),
        ("Jan", "http://localhost:1337/v1"),
    ]

    package var baseURL = "http://localhost:11434/v1"
    package var model = ""

    package var isConfigured: Bool {
        !baseURL.isEmpty && !model.isEmpty
    }

    package init(baseURL: String = "http://localhost:11434/v1", model: String = "") {
        self.baseURL = baseURL
        self.model = model
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? "http://localhost:11434/v1"
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
    }
}
