@testable import DictateCore
import Testing

struct TranscriptFilterTests {
    private func verdict(_ text: String, _ language: Language, logProbability: Double? = -0.3, ratio: Double? = 1.2)
        -> TranscriptFilter.Verdict {
        TranscriptFilter.verdict(text: text, language: language, averageLogProbability: logProbability, compressionRatio: ratio)
    }

    @Test func ordinaryTextIsKept() {
        #expect(verdict("Please send me the report.", .en) == .keep)
        #expect(verdict("Добрый день!", .ru) == .keep)
    }

    @Test func lowConfidenceIsDropped() {
        #expect(verdict("Something", .en, logProbability: -1.4) == .drop("low confidence"))
    }

    @Test func repetitiveTextIsDropped() {
        #expect(verdict("la la la la la", .en, ratio: 3.1) == .drop("repetitive text"))
    }

    @Test func unknownStatisticsDoNotDropText() {
        #expect(verdict("Hello", .en, logProbability: nil, ratio: nil) == .keep)
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
        #expect(verdict(text, language) == .drop("known hallucination"))
    }

    @Test func aStockPhraseInsideARealSentenceIsKept() {
        #expect(verdict("Thanks for watching my daughter while I was out.", .en) == .keep)
        #expect(verdict("Продолжение следует в следующем письме, жду ответа.", .ru) == .keep)
    }

    @Test func aCreditWithTooManyWordsIsKept() {
        #expect(verdict("Субтитры сделал он сам вчера вечером дома", .ru) == .keep)
    }

    @Test func aPlainThankYouIsKept() {
        #expect(verdict("Thank you.", .en) == .keep)
    }
}
