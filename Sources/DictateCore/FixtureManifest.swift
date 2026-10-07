import Foundation

/// One line of `fixtures/manifest.json`: a speech clip made with `say` and the text it says.
public struct Fixture: Decodable, Equatable, Sendable {
    public let id: String
    public let language: Language
    public let text: String
    /// Other spellings that are equally right (digits for numbers), for the character error rate.
    public let alternatives: [String]
    /// What the text should become in Clean mode (fillers and self-corrections gone), for clips that have them.
    public let clean: String?
    public let tags: [String]

    private enum CodingKeys: String, CodingKey {
        case id, language, text, alternatives, clean, tags
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        language = try container.decode(Language.self, forKey: .language)
        text = try container.decode(String.self, forKey: .text)
        alternatives = try container.decodeIfPresent([String].self, forKey: .alternatives) ?? []
        clean = try container.decodeIfPresent(String.self, forKey: .clean)
        tags = try container.decode([String].self, forKey: .tags)
    }

    public static func load(from url: URL) throws -> [Fixture] {
        try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
    }
}
