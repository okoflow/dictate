import Foundation

package enum WhisperPrompt {
    package static let maximumGlossaryLength = 200

    package static func text(for language: Language, vocabulary: [String]) -> String? {
        let parts = [styleSentence(for: language), glossary(from: vocabulary)].compactMap(\.self)

        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    package static func styleSentence(for language: Language) -> String? {
        switch language {
        case .chinese: "你好！这是一段示例文本，包含逗号和句号。"
        case .dutch: "Hallo! Dit is een voorbeeldtekst met hoofdletters, komma's en punten."
        case .english: "Hello! This is a sample of text, with capital letters, commas and full stops."
        case .french: "Bonjour ! Voici un exemple de texte avec des majuscules, des virgules et des points."
        case .german: "Hallo! Das ist ein Beispieltext mit Großbuchstaben, Kommas und Punkten."
        case .italian: "Ciao! Questo è un esempio di testo con lettere maiuscole, virgole e punti."
        case .japanese, .korean: nil
        case .polish: "Cześć! To jest przykładowy tekst z wielkimi literami, przecinkami i kropkami."
        case .portuguese: "Olá! Este é um texto de exemplo com letras maiúsculas, vírgulas e pontos finais."
        case .russian: "Привет! Это пример текста: с заглавными буквами, запятыми и точками."
        case .spanish: "¡Hola! ¿Qué tal? Este es un texto de ejemplo con mayúsculas, comas y puntos."
        case .ukrainian: "Привіт! Це приклад тексту з великими літерами, комами та крапками."
        }
    }

    private static func glossary(from terms: [String]) -> String? {
        var glossary = ""

        for term in terms.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !term.isEmpty {
            let extended = glossary.isEmpty ? term : glossary + ", " + term
            guard extended.count <= maximumGlossaryLength else { break }

            glossary = extended
        }

        return glossary.isEmpty ? nil : glossary + "."
    }
}
