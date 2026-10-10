struct OpenAIResponsesError: Decodable {
    struct Detail: Decodable {
        let message: String
        let type: String?
        let code: String?
    }

    let error: Detail
}
