import Foundation

/// A word (letters and digits, with inner hyphens and apostrophes: "кто-то", "don't") or the run of other
/// characters between two words. Joining the pieces of a text gives the text back.
struct TextPiece: Equatable {
    var text: String
    let isWord: Bool

    static func split(_ text: String) -> [TextPiece] {
        let characters = Array(text)
        var pieces: [TextPiece] = []
        for (index, character) in characters.enumerated() {
            let isWordCharacter = character.isLetter || character.isNumber || character.unicodeScalars.allSatisfy {
                $0.properties.generalCategory == .nonspacingMark
            } || isInnerJoiner(at: index, in: characters)
            if let last = pieces.last, last.isWord == isWordCharacter {
                pieces[pieces.count - 1].text.append(character)
            } else {
                pieces.append(TextPiece(text: String(character), isWord: isWordCharacter))
            }
        }
        return pieces
    }

    private static func isInnerJoiner(at index: Int, in characters: [Character]) -> Bool {
        guard ["-", "'", "’", "‐"].contains(characters[index]), index > 0, index + 1 < characters.count else { return false }
        let before = characters[index - 1]
        let after = characters[index + 1]
        return (before.isLetter || before.isNumber) && after.isLetter
    }
}
