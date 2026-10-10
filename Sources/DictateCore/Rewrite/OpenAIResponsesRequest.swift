struct OpenAIResponsesRequest: Encodable {
    struct Reasoning: Encodable {
        let effort: String
    }

    enum CodingKeys: String, CodingKey {
        case model
        case instructions
        case input
        case maximumOutputTokens = "max_output_tokens"
        case reasoning
        case store
    }

    let model: String
    let instructions: String
    let input: String
    let maximumOutputTokens: Int
    let reasoning: Reasoning
    let store: Bool
}
