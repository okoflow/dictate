import Foundation

extension String {
    package func capitalizingFirstLetter(in language: Language) -> String {
        guard let index = firstIndex(where: \.isLetter), self[index].isLowercase else { return self }

        let capital = language.hasDottedCapitalI && self[index] == "i" ? "İ" : self[index].uppercased()

        return replacingCharacters(in: index ... index, with: capital)
    }

    package func capitalizedIfUnstyled(in language: Language) -> String {
        let isUnstyled = !contains(where: \.isUppercase) && !contains(where: \.isPunctuation)

        return language.hasLetterCase && isUnstyled ? capitalizingFirstLetter(in: language) : self
    }
}
