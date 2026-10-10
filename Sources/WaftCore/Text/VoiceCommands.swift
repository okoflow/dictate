import Foundation

package enum VoiceCommands {
    private struct Command {
        let words: [String]
        let isParagraph: Bool
    }

    private static let lines: [Language: [String]] = [
        .czech: ["nový řádek"],
        .danish: ["ny linje"],
        .dutch: ["nieuwe regel"],
        .english: ["new line", "newline", "next line"],
        .finnish: ["uusi rivi"],
        .french: ["nouvelle ligne", "à la ligne"],
        .german: ["neue zeile", "nächste zeile"],
        .italian: ["nuova riga", "a capo"],
        .japanese: ["改行"],
        .korean: ["줄 바꿈", "줄바꿈"],
        .norwegian: ["ny linje"],
        .polish: ["nowa linia", "nowy wiersz"],
        .portuguese: ["nova linha"],
        .russian: ["новая строка", "с новой строки"],
        .spanish: ["nueva línea"],
        .swedish: ["ny rad"],
        .turkish: ["yeni satır"],
        .ukrainian: ["новий рядок", "з нового рядка"],
    ]

    private static let paragraphs: [Language: [String]] = [
        .chinese: ["新段落"],
        .czech: ["nový odstavec"],
        .danish: ["nyt afsnit"],
        .dutch: ["nieuwe alinea"],
        .english: ["new paragraph", "next paragraph"],
        .finnish: ["uusi kappale"],
        .french: ["nouveau paragraphe"],
        .german: ["neuer absatz"],
        .italian: ["nuovo paragrafo"],
        .japanese: ["新しい段落"],
        .korean: ["새 문단", "새 단락"],
        .norwegian: ["nytt avsnitt"],
        .polish: ["nowy akapit"],
        .portuguese: ["novo parágrafo"],
        .russian: ["новый абзац", "с нового абзаца"],
        .spanish: ["nuevo párrafo"],
        .swedish: ["nytt stycke"],
        .turkish: ["yeni paragraf"],
        .ukrainian: ["новий абзац", "з нового абзацу"],
    ]

    private static let pauseMarks: Set<Character> = [".", ",", "!", "?", ";", ":", "…", "。", "，", "、", "！", "？", "：", "；"]
    private static let joiningMarks: Set<Character> = [",", "，", "、", ";", "；", ":", "：", "-", "–", "—"]

    package static func apply(_ text: String, language: Language) -> String {
        let commands = commands(for: language)
        guard !commands.isEmpty else { return text }

        let segments = TextSegment.split(text)
        var result = ""
        var index = 0
        var capitalizesNext = false

        while index < segments.count {
            let segment = segments[index]

            if segment.isWord, let (command, end) = match(commands, at: index, in: segments) {
                result = endingLine(result, language: language, isParagraph: command.isParagraph)
                result += command.isParagraph ? "\n\n" : "\n"
                index = end + 1
                capitalizesNext = true
            } else if capitalizesNext, !segment.isWord {
                result += String(segment.text.filter { !pauseMarks.contains($0) && $0 != " " })
                index += 1
            } else {
                let capitalizes = capitalizesNext && language.hasLetterCase
                result += capitalizes ? segment.text.capitalizingFirstLetter(in: language) : segment.text
                capitalizesNext = false
                index += 1
            }
        }

        return result
    }

    private static func commands(for language: Language) -> [Command] {
        let lineCommands = (lines[language] ?? []).map { Command(words: words(of: $0), isParagraph: false) }
        let paragraphCommands = (paragraphs[language] ?? []).map { Command(words: words(of: $0), isParagraph: true) }

        return (lineCommands + paragraphCommands).sorted { $0.words.count > $1.words.count }
    }

    private static func words(of phrase: String) -> [String] {
        TextSegment.split(phrase).filter(\.isWord).map { normalized($0.text) }
    }

    private static func normalized(_ word: String) -> String {
        word.lowercased().replacingOccurrences(of: "ё", with: "е")
    }

    private static func match(_ commands: [Command], at start: Int, in segments: [TextSegment]) -> (Command, Int)? {
        guard isPause(before: start, in: segments) else { return nil }

        for command in commands {
            if let end = end(of: command, at: start, in: segments), isPause(after: end, in: segments) {
                return (command, end)
            }
        }

        return nil
    }

    private static func end(of command: Command, at start: Int, in segments: [TextSegment]) -> Int? {
        var index = start

        for (position, word) in command.words.enumerated() {
            if position > 0 {
                guard index + 2 < segments.count, segments[index + 1].text.allSatisfy(\.isWhitespace) else { return nil }

                index += 2
            }

            guard segments[index].isWord, normalized(segments[index].text) == word else { return nil }
        }

        return index
    }

    private static func isPause(before index: Int, in segments: [TextSegment]) -> Bool {
        index == 0 || segments[index - 1].text.contains { pauseMarks.contains($0) || $0 == "\n" }
    }

    private static func isPause(after index: Int, in segments: [TextSegment]) -> Bool {
        index + 1 >= segments.count || segments[index + 1].text.contains { pauseMarks.contains($0) || $0 == "\n" }
    }

    private static func endingLine(_ text: String, language: Language, isParagraph: Bool) -> String {
        var line = text

        while let last = line.last, last == " " || joiningMarks.contains(last) {
            line.removeLast()
        }

        if isParagraph, let last = line.last, last.isLetter || last.isNumber {
            line += language.fullStop
        }

        return line
    }
}
