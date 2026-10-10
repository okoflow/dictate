struct TextSegment: Equatable {
    private static let innerJoiners: Set<Character> = ["-", "'", "’", "‐", "\"", "׳", "״"]

    var text: String
    let isWord: Bool

    static func split(_ text: String) -> [TextSegment] {
        let characters = Array(text)
        var segments: [TextSegment] = []

        for index in characters.indices {
            let isWordCharacter = isWordCharacter(at: index, in: characters)

            if let last = segments.last, last.isWord == isWordCharacter {
                segments[segments.count - 1].text.append(characters[index])
            } else {
                segments.append(TextSegment(text: String(characters[index]), isWord: isWordCharacter))
            }
        }

        return segments
    }

    private static func isWordCharacter(at index: Int, in characters: [Character]) -> Bool {
        let character = characters[index]
        let isMark = character.unicodeScalars.allSatisfy { $0.properties.generalCategory == .nonspacingMark }

        return character.isLetter || character.isNumber || isMark || isInnerJoiner(at: index, in: characters)
    }

    private static func isInnerJoiner(at index: Int, in characters: [Character]) -> Bool {
        guard innerJoiners.contains(characters[index]), index > 0, index + 1 < characters.count else { return false }

        let before = characters[index - 1]
        let after = characters[index + 1]

        return (before.isLetter || before.isNumber) && after.isLetter
    }
}
