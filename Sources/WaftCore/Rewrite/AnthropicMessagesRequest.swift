struct AnthropicMessagesRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct Thinking: Encodable {
        let type: String
    }

    enum CodingKeys: String, CodingKey {
        case model
        case maximumTokens = "max_tokens"
        case thinking
        case system
        case messages
    }

    let model: String
    let maximumTokens: Int
    let thinking: Thinking
    let system: String
    let messages: [Message]
}
