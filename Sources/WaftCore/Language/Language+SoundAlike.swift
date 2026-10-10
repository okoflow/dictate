extension Language {
    private static let soundAlikeGroups: [[Language]] = [
        [.russian, .ukrainian],
        [.danish, .norwegian],
        [.indonesian, .malay],
        [.serbian, .croatian, .bosnian],
        [.czech, .slovak],
        [.bulgarian, .macedonian],
        [.hindi, .urdu],
    ]

    package static func soundAlike(among languages: [Language]) -> [Language]? {
        soundAlikeGroups
            .map { group in group.filter(languages.contains) }
            .first { $0.count > 1 }
    }
}
