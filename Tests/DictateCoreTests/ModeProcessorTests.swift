@testable import DictateCore
import Foundation
import Testing

/// Answers with a fixed result and counts its calls.
private final class FakeRewriter: TextRewriter {
    enum Behaviour {
        case answer(String)
        case fail(CloudError)
        case otherError
        case hang
    }

    private actor Calls {
        var modes: [Mode] = []

        func append(_ mode: Mode) {
            modes.append(mode)
        }
    }

    private let behaviour: Behaviour
    private let calls = Calls()

    init(_ behaviour: Behaviour) {
        self.behaviour = behaviour
    }

    var modes: [Mode] {
        get async { await calls.modes }
    }

    func rewrite(_: String, mode: Mode, language _: Language) async throws -> String {
        await calls.append(mode)
        switch behaviour {
        case let .answer(text): return text
        case let .fail(error): throw error
        case .otherError: throw URLError(.unknown)
        case .hang:
            try await Task.sleep(for: .seconds(30))
            return "too late"
        }
    }
}

struct ModeProcessorTests {
    private let filler = "Ну, это, значит, нужно, ээ, перенести созвон на четверг, нет, на пятницу."

    @Test func rawAndLightNeverCallTheRewriter() async {
        let rewriter = FakeRewriter(.answer("cloud"))
        let processor = ModeProcessor(rewriter: rewriter)
        let raw = await processor.process(filler, mode: .raw, language: .ru)
        let light = await processor.process(filler, mode: .light, language: .ru)
        #expect(raw == ProcessedText(text: filler, requested: .raw, applied: .raw, fallback: nil, contactedCloud: false))
        #expect(light.text == "Ну, это, значит, нужно перенести созвон на четверг, нет, на пятницу.")
        #expect(light.applied == .light && !light.contactedCloud && light.fallback == nil)
        #expect(await rewriter.modes.isEmpty)
    }

    @Test(arguments: [Mode.clean, .formal])
    func cloudModesUseTheAnswer(mode: Mode) async {
        let rewriter = FakeRewriter(.answer("Нужно перенести созвон на пятницу."))
        let result = await ModeProcessor(rewriter: rewriter).process(filler, mode: mode, language: .ru)
        #expect(result == ProcessedText(
            text: "Нужно перенести созвон на пятницу.", requested: mode, applied: mode, fallback: nil, contactedCloud: true
        ))
        #expect(await rewriter.modes == [mode])
    }

    @Test func translateExpectsEnglish() async {
        let english = await ModeProcessor(rewriter: FakeRewriter(.answer("We need to move the call to Friday.")))
            .process(filler, mode: .translate, language: .ru)
        #expect(english.applied == .translate)
        let untranslated = await ModeProcessor(rewriter: FakeRewriter(.answer("Нужно перенести созвон на пятницу.")))
            .process(filler, mode: .translate, language: .ru)
        #expect(untranslated.applied == .light && untranslated.fallback == .unusableAnswer)
    }

    @Test func noKeyFallsBackToLightWithoutContactingTheCloud() async {
        let result = await ModeProcessor(rewriter: nil).process("um, hello", mode: .clean, language: .en)
        #expect(result == ProcessedText(
            text: "Hello.", requested: .clean, applied: .light, fallback: .noKey, contactedCloud: false
        ))
    }

    @Test(arguments: [
        (CloudError.offline, FallbackReason.offline),
        (.timeout, .timeout),
        (.badKey, .badKey),
        (.rateLimited, .rateLimited),
        (.service(status: 529), .serviceError),
        (.truncated, .unusableAnswer),
        (.refused, .unusableAnswer),
        (.unreadableAnswer, .unusableAnswer),
    ])
    func errorsFallBackToLight(error: CloudError, reason: FallbackReason) async {
        let result = await ModeProcessor(rewriter: FakeRewriter(.fail(error))).process("um, hello", mode: .formal, language: .en)
        #expect(result == ProcessedText(
            text: "Hello.", requested: .formal, applied: .light, fallback: reason, contactedCloud: true
        ))
    }

    @Test func anUnexpectedErrorCountsAsOffline() async {
        let result = await ModeProcessor(rewriter: FakeRewriter(.otherError)).process("hello", mode: .clean, language: .en)
        #expect(result.fallback == .offline)
    }

    @Test func aSlowAnswerTimesOutAtTheDeadline() async {
        let start = ContinuousClock.now
        let result = await ModeProcessor(rewriter: FakeRewriter(.hang), timeout: .milliseconds(200))
            .process("uh, hello", mode: .clean, language: .en)
        #expect(result.fallback == .timeout)
        #expect(result.text == "Hello.")
        #expect(ContinuousClock.now - start < .seconds(5))
    }

    @Test func theDefaultDeadlineIsThreeSeconds() {
        #expect(ModeProcessor.cloudTimeout == .seconds(3))
    }

    @Test func everyFallbackHasAPillMessage() {
        let reasons: [FallbackReason] = [.noKey, .badKey, .offline, .timeout, .rateLimited, .serviceError, .unusableAnswer]
        for reason in reasons {
            #expect(reason.message.hasPrefix("Light: "))
        }
    }
}

struct CloudAnswerCheckTests {
    private func check(
        _ answer: String, _ input: String = "ну, привет", mode: Mode = .clean, _ language: Language = .ru
    ) -> String? {
        CloudAnswerCheck.accepted(answer, for: input, mode: mode, language: language)
    }

    @Test func aGoodAnswerIsKeptTrimmed() {
        #expect(check("  Привет.\n") == "Привет.")
    }

    @Test func wrappingTagsAndQuotesAreRemoved() {
        #expect(check("<transcript>Привет.</transcript>") == "Привет.")
        #expect(check("\"Привет.\"") == "Привет.")
        #expect(check("«Привет.»") == "Привет.")
        #expect(check("\"Привет,\" — сказал он.", "\"привет,\" сказал он") == "\"Привет,\" — сказал он.")
        #expect(check("\"Привет.\"", "\"привет\"") == "\"Привет.\"")
    }

    @Test func emptyOrRunawayAnswersAreRejected() {
        #expect(check("") == nil)
        #expect(check("<transcript></transcript>") == nil)
        #expect(check(String(repeating: "очень длинный ответ ", count: 10)) == nil)
    }

    @Test func aChangedLanguageIsRejected() {
        #expect(check("Hello.") == nil)
        #expect(check("안녕하세요.") == nil)
        #expect(check("Hello.", "hello", mode: .clean, .en) == "Hello.")
        #expect(check("Hello.", mode: .translate) == "Hello.")
        #expect(check("Привет.", mode: .translate) == nil)
    }

    @Test func anAnswerWithoutLettersIsNotJudgedOnScript() {
        #expect(check("12:30", "двенадцать тридцать") == "12:30")
    }
}
