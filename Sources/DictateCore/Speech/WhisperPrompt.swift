import Foundation

package enum WhisperPrompt {
    package static let maximumGlossaryLength = 200

    package static func text(for language: Language, vocabulary: [String]) -> String? {
        let parts = [styleSentence(for: language), glossary(from: vocabulary)].compactMap(\.self)

        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    package static func styleSentence(for language: Language) -> String? {
        styleSentences[language]
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

extension WhisperPrompt {
    fileprivate static let styleSentences: [Language: String] = [
        .arabic: "مرحبًا! كيف حالك؟ هذا مثال على نص مكتوب، فيه فواصل ونقاط.",
        .azerbaijani: "Salam! Bu, böyük hərflər, vergüllər və nöqtələr olan nümunə mətndir.",
        .bosnian: "Zdravo! Ovo je primjer teksta s velikim slovima, zarezima i tačkama.",
        .bulgarian: "Здравейте! Това е примерен текст с главни букви, запетаи и точки.",
        .catalan: "Hola! Aquest és un text d'exemple amb majúscules, comes i punts.",
        .chinese: "你好！这是一段示例文本，包含逗号和句号。",
        .croatian: "Bok! Ovo je primjer teksta s velikim slovima, zarezima i točkama.",
        .czech: "Ahoj! Toto je ukázkový text s velkými písmeny, čárkami a tečkami.",
        .danish: "Hej! Dette er en eksempeltekst med store bogstaver, kommaer og punktummer.",
        .dutch: "Hallo! Dit is een voorbeeldtekst met hoofdletters, komma's en punten.",
        .english: "Hello! This is a sample of text, with capital letters, commas and full stops.",
        .estonian: "Tere! See on näidistekst suurtähtede, komade ja punktidega.",
        .filipino: "Kumusta! Ito ay isang halimbawang teksto na may malalaking titik, kuwit, at tuldok.",
        .finnish: "Hei! Tämä on esimerkkiteksti, jossa on isoja kirjaimia, pilkkuja ja pisteitä.",
        .french: "Bonjour ! Voici un exemple de texte avec des majuscules, des virgules et des points.",
        .galician: "Ola! Este é un texto de exemplo con maiúsculas, comas e puntos.",
        .german: "Hallo! Das ist ein Beispieltext mit Großbuchstaben, Kommas und Punkten.",
        .greek: "Γεια σας! Τι κάνετε; Αυτό είναι ένα δείγμα κειμένου με κεφαλαία γράμματα, κόμματα και τελείες.",
        .hebrew: "שלום! זהו טקסט לדוגמה, עם פסיקים ונקודות.",
        .hindi: "नमस्ते! यह एक उदाहरण पाठ है, जिसमें अल्पविराम और पूर्ण विराम हैं।",
        .hungarian: "Szia! Ez egy példaszöveg nagybetűkkel, vesszőkkel és pontokkal.",
        .indonesian: "Halo! Ini adalah contoh teks dengan huruf kapital, koma, dan titik.",
        .italian: "Ciao! Questo è un esempio di testo con lettere maiuscole, virgole e punti.",
        .latvian: "Sveiki! Šis ir teksta piemērs ar lielajiem burtiem, komatiem un punktiem.",
        .lithuanian: "Labas! Tai teksto pavyzdys su didžiosiomis raidėmis, kableliais ir taškais.",
        .macedonian: "Здраво! Ова е пример на текст со големи букви, запирки и точки.",
        .malay: "Helo! Ini ialah contoh teks dengan huruf besar, koma dan noktah.",
        .norwegian: "Hei! Dette er en eksempeltekst med store bokstaver, komma og punktum.",
        .polish: "Cześć! To jest przykładowy tekst z wielkimi literami, przecinkami i kropkami.",
        .portuguese: "Olá! Este é um texto de exemplo com letras maiúsculas, vírgulas e pontos finais.",
        .romanian: "Bună! Acesta este un text de exemplu, cu majuscule, virgule și puncte.",
        .russian: "Привет! Это пример текста: с заглавными буквами, запятыми и точками.",
        .slovak: "Ahoj! Toto je ukážkový text s veľkými písmenami, čiarkami a bodkami.",
        .slovenian: "Pozdravljeni! To je primer besedila z velikimi začetnicami, vejicami in pikami.",
        .spanish: "¡Hola! ¿Qué tal? Este es un texto de ejemplo con mayúsculas, comas y puntos.",
        .swedish: "Hej! Det här är en exempeltext med stora bokstäver, kommatecken och punkter.",
        .tamil: "வணக்கம்! இது ஒரு மாதிரி உரை, இதில் காற்புள்ளிகளும் முற்றுப்புள்ளிகளும் உள்ளன.",
        .turkish: "Merhaba! İşte büyük harfler, virgüller ve noktalar içeren örnek bir metin.",
        .ukrainian: "Привіт! Це приклад тексту з великими літерами, комами та крапками.",
        .urdu: "السلام علیکم! یہ ایک نمونہ عبارت ہے، جس میں سکتے اور ختمے ہیں۔",
        .vietnamese: "Xin chào! Đây là một đoạn văn bản mẫu, có chữ hoa, dấu phẩy và dấu chấm.",
    ]
}
