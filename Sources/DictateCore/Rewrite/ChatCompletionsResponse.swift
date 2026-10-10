struct ChatCompletionsResponse: Decodable {
    struct Choice: Decodable {
        let message: Message
        let finishReason: String?
    }

    struct Message: Decodable {
        let content: String?
    }

    struct ModelList: Decodable {
        let data: [Model]
    }

    struct Model: Decodable {
        let id: String
    }

    let choices: [Choice]
}
