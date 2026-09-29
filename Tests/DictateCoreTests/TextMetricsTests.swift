@testable import DictateCore
import Foundation
import Testing

struct TextNormalisationTests {
    @Test func ignoresCaseAndPunctuation() {
        #expect(TextMetrics.normalise("Hello, World!", language: .en) == "hello world")
        #expect(TextMetrics.normalise("«Привет» — сказал он…", language: .ru) == "привет сказал он")
    }

    @Test func collapsesWhitespace() {
        #expect(TextMetrics.normalise("  a \t b\n\nc  ", language: .en) == "a b c")
    }

    @Test func mapsYoToYe() {
        #expect(TextMetrics.normalise("Всё ещё", language: .ru) == "все еще")
    }

    @Test func koreanIsComparedWithoutSpaces() {
        #expect(TextMetrics.normalise("안녕하세요, 오늘 회의는", language: .ko) == "안녕하세요오늘회의는")
    }

    @Test func composesDecomposedHangulAndAccents() {
        let decomposed = "\u{1112}\u{1161}\u{11AB}" // ᄒ + ᅡ + ᆫ, the syllable 한 written as three jamo
        #expect(TextMetrics.normalise(decomposed, language: .ko) == "한")
        #expect(TextMetrics.normalise("e\u{0301}", language: .en) == "\u{00E9}")
    }

    @Test func dropsSymbolsToo() {
        #expect(TextMetrics.normalise("2 + 2 = 4, 20° $5 №7", language: .en) == "2 2 4 20 5 7")
    }

    @Test func keepsDigitsAndLetters() {
        #expect(TextMetrics.normalise("3 o'clock", language: .en) == "3 oclock")
    }
}

struct CharacterErrorRateTests {
    @Test func identicalTextsScoreZero() {
        #expect(TextMetrics.cer(reference: "Good day.", hypothesis: "good day", language: .en) == 0)
    }

    @Test func oneSubstitutionOutOfTen() {
        let rate = TextMetrics.cer(reference: "abcdefghij", hypothesis: "abcdefghix", language: .en)
        #expect(abs(rate - 0.1) < 1e-9)
    }

    @Test func countsInsertionsAndDeletions() {
        #expect(abs(TextMetrics.cer(reference: "abcd", hypothesis: "abcde", language: .en) - 0.25) < 1e-9)
        #expect(abs(TextMetrics.cer(reference: "abcd", hypothesis: "abd", language: .en) - 0.25) < 1e-9)
    }

    @Test func emptyReferenceIsZeroOnlyForEmptyHypothesis() {
        #expect(TextMetrics.cer(reference: "", hypothesis: "", language: .en) == 0)
        #expect(TextMetrics.cer(reference: "...", hypothesis: "x", language: .en) == 1)
    }

    @Test func completelyWrongTextCanExceedOne() {
        #expect(TextMetrics.cer(reference: "ab", hypothesis: "xyzxyz", language: .en) > 1)
    }

    @Test func koreanSpacingIsNotAnError() {
        let rate = TextMetrics.cer(reference: "오늘 회의는 시작합니다", hypothesis: "오늘회의는 시작 합니다.", language: .ko)
        #expect(rate == 0)
    }

    @Test func alternativesTakeTheBestMatch() {
        let rate = TextMetrics.cer(
            reference: "встреча в три часа",
            alternatives: ["встреча в 3 часа"],
            hypothesis: "Встреча в 3 часа.",
            language: .ru
        )
        #expect(rate == 0)
        let withoutAlternatives = TextMetrics.cer(reference: "встреча в три часа", hypothesis: "Встреча в 3 часа.", language: .ru)
        #expect(withoutAlternatives > 0)
    }

    @Test func noAlternativesFallsBackToTheReference() {
        let rate = TextMetrics.cer(reference: "abcd", alternatives: [], hypothesis: "abcx", language: .en)
        #expect(abs(rate - 0.25) < 1e-9)
    }
}
