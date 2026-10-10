struct ChatCompletionsRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maximumTokens = "max_tokens"
        case stream
    }

    let model: String
    let messages: [Message]
    let temperature: Double
    let maximumTokens: Int
    let stream: Bool
}
