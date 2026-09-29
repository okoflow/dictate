@testable import DictateCore
import Testing

struct LanguageTests {
    @Test func picksTheMostProbableOfOurThree() throws {
        let picked = try #require(Language.pick(from: ["en": 0.1, "ru": 0.7, "ko": 0.05]))
        #expect(picked.language == .ru)
        #expect(picked.probability == 0.7)
    }

    @Test func otherLanguagesNeverWin() throws {
        // Ukrainian sounds like Russian and Japanese like Korean; the model may rank them first.
        let picked = try #require(Language.pick(from: ["uk": 0.6, "ru": 0.3, "ja": 0.5, "ko": 0.05, "en": 0.01]))
        #expect(picked.language == .ru)
    }

    @Test func worksWithLogProbabilitiesToo() throws {
        let picked = try #require(Language.pick(from: ["en": -0.2, "ru": -3, "ko": -9]))
        #expect(picked.language == .en)
    }

    @Test func nilWhenNoneOfOursIsPresent() {
        #expect(Language.pick(from: ["fr": 0.9, "de": 0.1]) == nil)
        #expect(Language.pick(from: [:]) == nil)
    }

    @Test func aMissingLanguageDoesNotBreakThePick() throws {
        let picked = try #require(Language.pick(from: ["ko": 0.2]))
        #expect(picked.language == .ko)
    }
}

struct LanguagePreferenceTests {
    @Test func roundTripsThroughStoredValue() {
        for choice in LanguagePreference.allChoices {
            #expect(LanguagePreference(storedValue: choice.storedValue) == choice)
        }
    }

    @Test func unknownOrMissingValueMeansAuto() {
        #expect(LanguagePreference(storedValue: nil) == .auto)
        #expect(LanguagePreference(storedValue: "klingon") == .auto)
    }

    @Test func choicesStartWithAutoThenEveryLanguage() {
        #expect(LanguagePreference.allChoices == [.auto, .fixed(.ru), .fixed(.en), .fixed(.ko)])
    }

    @Test func languageIsOnlySetWhenPinned() {
        #expect(LanguagePreference.auto.language == nil)
        #expect(LanguagePreference.fixed(.ko).language == .ko)
    }

    @Test func menuTitlesAreDistinct() {
        let titles = LanguagePreference.allChoices.map(\.menuTitle)
        #expect(Set(titles).count == titles.count)
        #expect(LanguagePreference.fixed(.ru).menuTitle == "Russian")
    }
}
