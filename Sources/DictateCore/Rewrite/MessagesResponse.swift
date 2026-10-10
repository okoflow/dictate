struct MessagesResponse: Decodable {
    struct Block: Decodable {
        let type: String
        let text: String?
    }

    enum CodingKeys: String, CodingKey {
        case content
        case stopReason = "stop_reason"
    }

    let content: [Block]
    let stopReason: String?
}
