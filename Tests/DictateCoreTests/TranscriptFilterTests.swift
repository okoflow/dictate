@testable import DictateCore
import Testing

struct TranscriptFilterTests {
    private func isHallucination(_ text: String, _ language: Language) -> Bool {
        TranscriptFilter.isKnownHallucination(text, language: language)
    }

    @Test func aConfidentPlainSegmentIsKept() {
        #expect(TranscriptFilter.keepsSegment(averageLogProbability: -0.3, compressionRatio: 1.2))
        #expect(TranscriptFilter.keepsSegment(averageLogProbability: -1.5, compressionRatio: 2.4))
    }

    @Test func aLowConfidenceSegmentIsDropped() {
        #expect(!TranscriptFilter.keepsSegment(averageLogProbability: -1.6, compressionRatio: 1.2))
    }

    @Test func aRepetitiveSegmentIsDropped() {
        #expect(!TranscriptFilter.keepsSegment(averageLogProbability: -0.3, compressionRatio: 3.1))
    }

    @Test(arguments: [
        ("Продолжение следует...", Language.ru),
        ("Субтитры сделал DimaTorzok", .ru),
        ("Субтитры создавал Sergey Ivanov", .ru),
        ("Thanks for watching!", .en),
        ("Thank you for watching.", .en),
        ("시청해 주셔서 감사합니다.", .ko),
        ("시청해주셔서 감사합니다", .ko),
    ])
    func stockPhrasesAreDropped(text: String, language: Language) {
        #expect(isHallucination(text, language))
    }

    @Test func aStockPhraseInsideARealSentenceIsKept() {
        #expect(!isHallucination("Thanks for watching my daughter while I was out.", .en))
        #expect(!isHallucination("Продолжение следует в следующем письме, жду ответа.", .ru))
    }

    @Test func aCreditWithTooManyWordsIsKept() {
        #expect(!isHallucination("Субтитры сделал он сам вчера вечером дома", .ru))
    }

    @Test func aPlainThankYouIsKept() {
        #expect(!isHallucination("Thank you.", .en))
    }
}

struct CapitalisationTests {
    @Test func aBareLowercaseTextGetsACapital() {
        #expect(TranscriptFilter.capitalisedIfUnstyled("привет как дела", language: .ru) == "Привет как дела")
        #expect(TranscriptFilter.capitalisedIfUnstyled("hello there", language: .en) == "Hello there")
    }

    @Test func aLeadingDigitOrQuoteIsSkippedToTheFirstLetter() {
        #expect(TranscriptFilter.capitalisedIfUnstyled("3 apples", language: .en) == "3 Apples")
    }

    @Test func anyPunctuationMeansTheTextIsLeftAlone() {
        #expect(TranscriptFilter.capitalisedIfUnstyled("hello, there", language: .en) == "hello, there")
        #expect(TranscriptFilter.capitalisedIfUnstyled("да.", language: .ru) == "да.")
    }

    @Test func anyCapitalMeansTheTextIsLeftAlone() {
        #expect(TranscriptFilter.capitalisedIfUnstyled("i met John", language: .en) == "i met John")
    }

    @Test func koreanIsNeverTouched() {
        #expect(TranscriptFilter.capitalisedIfUnstyled("안녕하세요 반갑습니다", language: .ko) == "안녕하세요 반갑습니다")
    }

    @Test func textWithoutLettersStaysAsItIs() {
        #expect(TranscriptFilter.capitalisedIfUnstyled("123", language: .en) == "123")
    }
}

struct PunctuationMetricsTests {
    @Test func countsSentenceEndsAndCommas() {
        let counts = PunctuationMetrics.counts(in: "Hi, all. How are you? Fine! Well… ok, 안녕。")
        #expect(counts == PunctuationMetrics.Counts(sentenceEnds: 5, commas: 2))
    }

    @Test func matchedCannotExceedTheReference() {
        let reference = PunctuationMetrics.Counts(sentenceEnds: 2, commas: 1)
        let hypothesis = PunctuationMetrics.Counts(sentenceEnds: 5, commas: 0)
        #expect(PunctuationMetrics.matched(reference: reference, hypothesis: hypothesis) == .init(sentenceEnds: 2, commas: 0))
    }

    @Test func startingCaseLooksAtTheFirstLetter() {
        #expect(PunctuationMetrics.startingCase(of: "Привет") == .upper)
        #expect(PunctuationMetrics.startingCase(of: "привет") == .lower)
        #expect(PunctuationMetrics.startingCase(of: "«Да") == .upper)
        #expect(PunctuationMetrics.startingCase(of: "안녕") == .uncased)
        #expect(PunctuationMetrics.startingCase(of: "42") == .uncased)
    }
}

struct StylePromptTests {
    @Test func everyLanguageHasACapitalisedPunctuatedPrompt() {
        for language in Language.allCases {
            let prompt = StylePrompt.text(for: language)
            #expect(PunctuationMetrics.counts(in: prompt).sentenceEnds >= 1)
            #expect(PunctuationMetrics.counts(in: prompt).commas >= 1 || language == .ru)
        }
        #expect(PunctuationMetrics.startingCase(of: StylePrompt.text(for: .ru)) == .upper)
        #expect(PunctuationMetrics.startingCase(of: StylePrompt.text(for: .en)) == .upper)
    }
}
