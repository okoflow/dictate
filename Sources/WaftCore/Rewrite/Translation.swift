package struct Translation: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case target
        case twoWayLanguage
    }

    package var target = Language.english
    package var twoWayLanguage: Language?

    package init(target: Language = .english, twoWayLanguage: Language? = nil) {
        self.target = target
        self.twoWayLanguage = twoWayLanguage == target ? nil : twoWayLanguage
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let target = (try? container.decodeIfPresent(Language.self, forKey: .target)) ?? .english
        let twoWayLanguage = try? container.decodeIfPresent(Language.self, forKey: .twoWayLanguage)

        self.init(target: target, twoWayLanguage: twoWayLanguage)
    }

    package func target(forSpoken spoken: Language) -> Language {
        guard spoken == target, let twoWayLanguage else { return target }

        return twoWayLanguage
    }
}
