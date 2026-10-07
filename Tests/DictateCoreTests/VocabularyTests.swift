@testable import DictateCore
import Foundation
import Testing

struct VocabularyTests {
    private let vocabulary = Vocabulary(
        terms: [
            .init(term: "Kubernetes", spoken: ["кубернетис", "кубер", "쿠버네티스"]),
            .init(term: "PostgreSQL", spoken: ["postgre sql", "постгрес"]),
            .init(term: "GitHub"),
            .init(term: "TypeScript", spoken: ["тайп скрипт"]),
            .init(term: "C++", spoken: ["си плюс плюс"]),
        ],
        snippets: [
            .init(trigger: "моя почта", text: "ivan.petrov@example.com"),
            .init(trigger: "my address", text: "1 Main St"),
        ]
    )

    @Test(arguments: [
        ("Задеплой сервис в кубернетис до вечера.", "Задеплой сервис в Kubernetes до вечера."),
        ("Кубер упал", "Kubernetes упал"),
        ("Update Postgre SQL and push to github", "Update PostgreSQL and push to GitHub"),
        ("Обнови постгрес", "Обнови PostgreSQL"),
        ("Пишем на тайп скрипт, не на тайп", "Пишем на TypeScript, не на тайп"),
        ("쿠버네티스를 업데이트해요", "Kubernetes를 업데이트해요"),
        ("Учу си плюс плюс", "Учу C++"),
        ("КУБЕРНЕТИС", "Kubernetes"),
    ])
    func spokenFormsAreReplaced(input: String, expected: String) {
        #expect(vocabulary.correcting(input) == expected)
    }

    @Test func partsOfWordsAndSplitPhrasesAreLeftAlone() {
        #expect(vocabulary.correcting("кубернетисы и кубера") == "кубернетисы и кубера")
        #expect(vocabulary.correcting("postgre, sql") == "postgre, sql")
        #expect(vocabulary.correcting("C and c") == "C and c")
    }

    @Test func aKoreanSuffixIsKeptOnlyForAParticle() {
        #expect(vocabulary.correcting("쿠버네티스에서") == "Kubernetes에서")
        #expect(vocabulary.correcting("쿠버네티스입니다요") == "쿠버네티스입니다요")
    }

    @Test func wholeSnippetsIgnoreCaseAndPunctuation() {
        #expect(vocabulary.wholeSnippet(for: "Моя почта.") == "ivan.petrov@example.com")
        #expect(vocabulary.wholeSnippet(for: "  моя   ПОЧТА!") == "ivan.petrov@example.com")
        #expect(vocabulary.wholeSnippet(for: "Моя почта сломалась.") == nil)
        #expect(vocabulary.wholeSnippet(for: "...") == nil)
    }

    @Test func snippetsExpandInsideText() {
        #expect(vocabulary.expandingSnippets(in: "Send it to my address, please.") == "Send it to 1 Main St, please.")
        #expect(Vocabulary.empty.expandingSnippets(in: "my address") == "my address")
    }

    @Test func promptTermsAreTheTerms() {
        #expect(vocabulary.promptTerms == ["Kubernetes", "PostgreSQL", "GitHub", "TypeScript", "C++"])
    }

    @Test func decodesTheFileWithMissingParts() throws {
        let json = #"{"terms": [{"term": "Jira"}, {"term": "Kubernetes", "spoken": ["кубер"]}]}"#
        let decoded = try JSONDecoder().decode(Vocabulary.self, from: Data(json.utf8))
        #expect(decoded.terms == [.init(term: "Jira"), .init(term: "Kubernetes", spoken: ["кубер"])])
        #expect(decoded.snippets.isEmpty)
        #expect(try JSONDecoder().decode(Vocabulary.self, from: Data("{}".utf8)) == .empty)
    }
}

struct WhisperPromptTests {
    @Test func styleSentenceAndTerms() {
        let english = StylePrompt.text(for: .en).map { $0 + " Kubernetes, Jira." }
        #expect(WhisperPrompt.text(for: .en, terms: ["Kubernetes", "Jira"]) == english)
        #expect(WhisperPrompt.text(for: .ru, terms: []) == StylePrompt.text(for: .ru))
        #expect(WhisperPrompt.text(for: .ko, terms: ["쿠버네티스"]) == "쿠버네티스.")
        #expect(WhisperPrompt.text(for: .ko, terms: [" "]) == nil)
    }

    @Test func termsAreCutToTheLimit() throws {
        let terms = (1 ... 100).map { "Term\($0)" }
        let text = try #require(WhisperPrompt.text(for: .ko, terms: terms))
        #expect(text.count <= WhisperPrompt.maximumTermCharacters + 1)
        #expect(text.hasPrefix("Term1, Term2,"))
    }
}

struct DictationHistoryTests {
    private func entry(_ text: String) -> DictationHistory.Entry {
        .init(date: Date(timeIntervalSince1970: 0), text: text, mode: .light, app: "com.apple.TextEdit")
    }

    @Test func keepsTheNewestUpToCapacity() {
        var history = DictationHistory()
        for number in 1 ... DictationHistory.capacity + 5 {
            history.add(entry("text \(number)"))
        }
        #expect(history.entries.count == DictationHistory.capacity)
        #expect(history.newest(2).map(\.text) == ["text 55", "text 54"])
        #expect(history.entries.first?.text == "text 6")
    }

    @Test func emptyTextsAreNotKeptAndClearEmpties() {
        var history = DictationHistory()
        history.add(entry(""))
        #expect(history.entries.isEmpty)
        history.add(entry("hello"))
        history.clear()
        #expect(history.entries.isEmpty)
    }

    @Test func roundTripsThroughJSON() throws {
        var history = DictationHistory()
        history.add(entry("привет"))
        let decoded = try JSONDecoder().decode(DictationHistory.self, from: JSONEncoder().encode(history))
        #expect(decoded == history)
        let entry = try #require(decoded.entries.first)
        #expect(entry.date == Date(timeIntervalSince1970: 0))
        #expect(entry.mode == .light)
        #expect(entry.app == "com.apple.TextEdit")
    }

    @Test func menuTitlesAreOneShortLine() {
        #expect(entry("one\ntwo").menuTitle == "one two")
        #expect(entry(String(repeating: "a", count: 80)).menuTitle == String(repeating: "a", count: 49) + "…")
    }
}

struct AppModesTests {
    @Test func storedAndLaunchValues() {
        let stored = AppModes(stored: ["com.google.Chrome": "formal", "com.apple.Terminal": "loud"])
        #expect(stored.modes == ["com.google.Chrome": .formal])
        #expect(stored.stored == ["com.google.Chrome": "formal"])
        let launched = AppModes(launchValue: "com.google.Chrome=light, com.apple.Terminal=raw,bad,x=nope")
        #expect(launched.modes == ["com.google.Chrome": .light, "com.apple.Terminal": .raw])
    }

    @Test func lookupAndChanges() {
        var modes = AppModes()
        #expect(modes.mode(for: "com.google.Chrome") == nil)
        #expect(modes.mode(for: nil) == nil)
        modes.set(.clean, for: "com.google.Chrome")
        #expect(modes.mode(for: "com.google.Chrome") == .clean)
        modes.set(nil, for: "com.google.Chrome")
        #expect(modes.modes.isEmpty)
    }

    @Test func launchOptions() {
        let arguments = ["--app-mode", "com.google.Chrome=light", "--dictionary", "/tmp/d.json"]
        let options = LaunchOptions(arguments: arguments, environment: [:])
        #expect(options.appModes == AppModes(modes: ["com.google.Chrome": .light]))
        #expect(options.dictionaryFile == "/tmp/d.json")
        #expect(LaunchOptions(arguments: ["--history-file", "/tmp/h.json"], environment: [:]).historyFile == "/tmp/h.json")
    }

    @Test func newEventsRoundTrip() throws {
        let events: [AppEvent] = [.appModeUsed(app: "com.google.Chrome", mode: .light), .snippetExpanded]
        #expect(try AppEvent.parseLog(events.map { try $0.jsonLine() }.joined()) == events)
    }
}
