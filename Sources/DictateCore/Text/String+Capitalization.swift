import Foundation

extension String {
    package func capitalizingFirstLetter() -> String {
        guard let index = firstIndex(where: \.isLetter), self[index].isLowercase else { return self }

        return replacingCharacters(in: index ... index, with: self[index].uppercased())
    }

    package func capitalizedIfUnstyled(in language: Language) -> String {
        let isUnstyled = !contains(where: \.isUppercase) && !contains(where: \.isPunctuation)

        return language.hasLetterCase && isUnstyled ? capitalizingFirstLetter() : self
    }
}
