struct AnthropicMessagesError: Decodable {
    struct Detail: Decodable {
        let type: String
        let message: String
    }

    let error: Detail
}
