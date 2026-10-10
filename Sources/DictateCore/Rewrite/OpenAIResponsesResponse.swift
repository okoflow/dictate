struct OpenAIResponsesResponse: Decodable {
    struct IncompleteDetails: Decodable {
        let reason: String?
    }

    struct Item: Decodable {
        let type: String
        let content: [Content]?
    }

    struct Content: Decodable {
        let type: String
        let text: String?
    }

    enum CodingKeys: String, CodingKey {
        case status
        case incompleteDetails = "incomplete_details"
        case output
    }

    let status: String?
    let incompleteDetails: IncompleteDetails?
    let output: [Item]
}
