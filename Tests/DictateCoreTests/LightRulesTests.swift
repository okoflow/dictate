@testable import DictateCore
import Testing

struct LightRulesTests {
    private func light(_ text: String, _ language: Language) -> String {
        LightRules.apply(text, language: language)
    }

    // MARK: Russian

    @Test(arguments: [
        ("Ну, это, значит, нужно, ээ, перенести созвон на четверг, нет, на пятницу.",
         "Ну, это, значит, нужно перенести созвон на четверг, нет, на пятницу."),
        ("Ээ, давай созвонимся завтра", "Давай созвонимся завтра."),
        ("Я думаю... эээ... что да", "Я думаю что да."),
        ("Отправь отчёт, мм, до вечера.", "Отправь отчёт до вечера."),
        ("Хм, интересно, э-э, почему", "Интересно почему."),
        ("Готово. Эм, следующий пункт", "Готово. Следующий пункт."),
        ("Мы закончили, э.", "Мы закончили."),
    ])
    func russianHesitationsAreRemoved(input: String, expected: String) {
        #expect(light(input, .ru) == expected)
    }

    @Test func millimetresAfterANumberAreKept() {
        #expect(light("Диаметр 5 мм, длина 10 мм", .ru) == "Диаметр 5 мм, длина 10 мм.")
    }

    @Test func realRussianWordsAreKept() {
        let text = "Эмоции, эхо и мэр: хмурый день, а ну-ка, это значит много."
        #expect(light(text, .ru) == text)
    }

    // MARK: English

    @Test(arguments: [
        ("So, um, we should, uh, move the call to Thursday, no, wait, to Friday.",
         "So we should move the call to Thursday, no, wait, to Friday."),
        ("Um, I think so", "I think so."),
        ("Ummm... let me check, hmm.", "Let me check."),
        ("We, er, erm, need more time", "We need more time."),
        ("uhh okay", "Okay."),
        ("Done. Uh, next one", "Done. Next one."),
    ])
    func englishHesitationsAreRemoved(input: String, expected: String) {
        #expect(light(input, .en) == expected)
    }

    @Test func realEnglishWordsAreKept() {
        let text = "Uber, umbrella, hummus, error, here, summer and the mmWave band."
        #expect(light(text, .en) == text)
    }

    // MARK: Korean

    @Test(arguments: [
        ("그러니까, 음, 회의를 목요일로, 아니, 금요일로 옮겨야 해요.", "그러니까 회의를 목요일로, 아니, 금요일로 옮겨야 해요."),
        ("음 회의를 어 금요일로 옮겨야 해요", "회의를 금요일로 옮겨야 해요."),
        ("으음, 내일 봐요.", "내일 봐요."),
        ("흠... 좋아요", "좋아요."),
    ])
    func koreanHesitationsAreRemoved(input: String, expected: String) {
        #expect(light(input, .ko) == expected)
    }

    @Test func koreanWordSpacingIsKept() {
        // 띄어쓰기: removing 음 neither glues two words nor leaves two spaces, and words that contain 음 or 어 stay.
        #expect(light("오늘  음  음식을   어디서 먹을까요", .ko) == "오늘 음식을 어디서 먹을까요.")
        #expect(light("지난주 보고서를 보내 주세요.", .ko) == "지난주 보고서를 보내 주세요.")
    }

    @Test func koreanIsNotCapitalised() {
        #expect(light("ok 좋아요", .ko) == "ok 좋아요.")
    }

    // MARK: Tidying

    @Test func spacingIsTidied() {
        #expect(light("hello ,  world  !", .en) == "Hello, world!")
        #expect(light("  привет  ", .ru) == "Привет.")
    }

    @Test func newlinesAreKept() {
        #expect(light("first line\nsecond line", .en) == "First line\nsecond line.")
    }

    @Test func onlyAFinalLetterOrDigitGetsAFullStop() {
        #expect(light("Call me at 5", .en) == "Call me at 5.")
        #expect(light("Is it done?", .en) == "Is it done?")
        #expect(light("He said \"yes\"", .en) == "He said \"yes\"")
        #expect(light("(see above)", .en) == "(See above)")
    }

    @Test func onlyHesitationsGiveAnEmptyText() {
        #expect(light("Um, uh...", .en).isEmpty)
        #expect(light("", .ru).isEmpty)
    }

    @Test(arguments: [
        "ээ", "Эээ", "э-э", "эм", "ммм", "хм", "um", "UMM", "uh", "uhm", "er", "erm", "hmm", "mm", "음", "으음", "어", "흠",
    ])
    func hesitationWords(word: String) {
        #expect(LightRules.isHesitation(word))
    }

    @Test(arguments: ["это", "ну", "мэр", "м", "u", "umbrella", "hum", "her", "음식", "어디", "아니"])
    func notHesitationWords(word: String) {
        #expect(!LightRules.isHesitation(word))
    }
}
